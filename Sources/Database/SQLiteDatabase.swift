import Core
import Foundation
import SQLite3

/// SQLite implementation of `DatabaseProtocol` without ORM.
public actor SQLiteDatabase: DatabaseProtocol {
    private var connection: OpaquePointer?
    private let migrations: [any DatabaseMigration]

    public init(migrations: [any DatabaseMigration] = [InitialMigration()]) {
        self.migrations = migrations
    }

    public func open(at url: URL) async throws {
        if connection != nil {
            try await close()
        }

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(url.path, &database, flags, nil)
        guard result == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            throw ProjectMindError.databaseOpenFailed(path: url.path, underlying: message)
        }

        connection = database
    }

    public func close() async throws {
        guard let connection else { return }
        sqlite3_close(connection)
        self.connection = nil
    }

    public func createTables() async throws {
        let connection = try requireConnection()
        try MigrationRunner(connection: connection).run(migrations: migrations)
    }

    public func insertFile(_ file: ProjectFile) async throws -> Int64 {
        let connection = try requireConnection()
        return try SQLiteExecutor(connection: connection).insertFile(file)
    }

    public func updateFile(id: Int64, file: ProjectFile) async throws {
        let connection = try requireConnection()
        try SQLiteExecutor(connection: connection).updateFile(id: id, file: file)
    }

    public func deleteFile(id: Int64) async throws {
        let connection = try requireConnection()
        try SQLiteExecutor(connection: connection).deleteFile(id: id)
    }

    public func query(_ query: FileQuery) async throws -> [StoredFile] {
        let connection = try requireConnection()
        return try SQLiteExecutor(connection: connection).query(query)
    }

    public func transaction<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        let connection = try requireConnection()
        let executor = SQLiteExecutor(connection: connection)

        try executor.execute(SQLStatements.beginTransaction)
        do {
            let result = try await operation()
            try executor.execute(SQLStatements.commitTransaction)
            return result
        } catch {
            try? executor.execute(SQLStatements.rollbackTransaction)
            throw error
        }
    }

    private func requireConnection() throws -> OpaquePointer {
        guard let connection else {
            throw ProjectMindError.databaseNotOpen
        }
        return connection
    }
}
