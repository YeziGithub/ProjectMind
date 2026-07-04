import Core
import Foundation
import SQLite3

/// Applies pending database migrations in version order.
struct MigrationRunner: Sendable {
    private let connection: OpaquePointer
    private let dateFormatter: ISO8601DateFormatter

    init(connection: OpaquePointer) {
        self.connection = connection
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func run(migrations: [any DatabaseMigration]) throws {
        let sorted = migrations.sorted { $0.version < $1.version }
        let applied = try fetchAppliedVersions()

        for migration in sorted {
            guard !applied.contains(migration.version) else { continue }
            try apply(migration)
        }
    }

    private func fetchAppliedVersions() throws -> Set<Int> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            connection,
            SQLStatements.selectAppliedMigrationVersions,
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement else {
            throw ProjectMindError.migrationFailed(version: 0, underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        var versions = Set<Int>()
        while sqlite3_step(statement) == SQLITE_ROW {
            versions.insert(Int(sqlite3_column_int64(statement, 0)))
        }
        return versions
    }

    private func apply(_ migration: any DatabaseMigration) throws {
        for sql in migration.statements {
            try execute(sql)
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            connection,
            SQLStatements.insertMigration,
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement else {
            throw ProjectMindError.migrationFailed(
                version: migration.version,
                underlying: lastErrorMessage()
            )
        }
        defer { sqlite3_finalize(statement) }

        let appliedAt = dateFormatter.string(from: .now)
        guard sqlite3_bind_int64(statement, 1, Int64(migration.version)) == SQLITE_OK,
              bindText(appliedAt, to: statement, at: 2) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw ProjectMindError.migrationFailed(
                version: migration.version,
                underlying: lastErrorMessage()
            )
        }
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(connection, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage()
            sqlite3_free(errorMessage)
            throw ProjectMindError.databaseExecuteFailed(underlying: message)
        }
    }

    private func bindText(_ value: String, to statement: OpaquePointer, at index: Int32) -> Int32 {
        value.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, Self.transientDestructor)
        }
    }

    private func lastErrorMessage() -> String {
        String(cString: sqlite3_errmsg(connection))
    }

    private static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
