import Core
import Foundation
import SQLite3

/// Low-level SQLite execution helpers shared by database operations.
struct SQLiteExecutor: Sendable {
    private let connection: OpaquePointer
    private let dateFormatter: ISO8601DateFormatter

    init(connection: OpaquePointer) {
        self.connection = connection
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(connection, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage()
            sqlite3_free(errorMessage)
            throw ProjectMindError.databaseExecuteFailed(underlying: message)
        }
    }

    func insertFile(_ file: ProjectFile) throws -> Int64 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, SQLStatements.insertFile, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let modifiedDate = dateFormatter.string(from: file.modifiedDate)
        guard bindText(file.path, to: statement, at: 1) == SQLITE_OK,
              bindText(file.filename, to: statement, at: 2) == SQLITE_OK,
              bindText(file.ext, to: statement, at: 3) == SQLITE_OK,
              sqlite3_bind_int64(statement, 4, file.size) == SQLITE_OK,
              bindText(modifiedDate, to: statement, at: 5) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }

        return sqlite3_last_insert_rowid(connection)
    }

    func updateFile(id: Int64, file: ProjectFile) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, SQLStatements.updateFile, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let modifiedDate = dateFormatter.string(from: file.modifiedDate)
        guard bindText(file.path, to: statement, at: 1) == SQLITE_OK,
              bindText(file.filename, to: statement, at: 2) == SQLITE_OK,
              bindText(file.ext, to: statement, at: 3) == SQLITE_OK,
              sqlite3_bind_int64(statement, 4, file.size) == SQLITE_OK,
              bindText(modifiedDate, to: statement, at: 5) == SQLITE_OK,
              sqlite3_bind_int64(statement, 6, id) == SQLITE_OK
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        guard sqlite3_changes(connection) > 0 else {
            throw ProjectMindError.fileNotFound(id: id)
        }
    }

    func deleteFile(id: Int64) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, SQLStatements.deleteFile, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_bind_int64(statement, 1, id) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        guard sqlite3_changes(connection) > 0 else {
            throw ProjectMindError.fileNotFound(id: id)
        }
    }

    func query(_ query: FileQuery) throws -> [StoredFile] {
        var sql = SQLStatements.selectFilesBase
        var bindings: [Binding] = []

        if let path = query.path {
            sql += " AND path = ?"
            bindings.append(.text(path))
        }
        if let filename = query.filename {
            sql += " AND filename = ?"
            bindings.append(.text(filename))
        }
        if let ext = query.ext {
            sql += " AND ext = ?"
            bindings.append(.text(ext))
        }

        sql += " ORDER BY id LIMIT ? OFFSET ?;"
        bindings.append(.int(Int64(query.limit)))
        bindings.append(.int(Int64(query.offset)))

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseQueryFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        var results: [StoredFile] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let stored = readStoredFile(from: statement) else {
                continue
            }
            results.append(stored)
        }
        return results
    }

    private func readStoredFile(from statement: OpaquePointer) -> StoredFile? {
        guard let path = columnText(statement, index: 1),
              let filename = columnText(statement, index: 2),
              let ext = columnText(statement, index: 3),
              let modifiedDateText = columnText(statement, index: 5),
              let modifiedDate = dateFormatter.date(from: modifiedDateText)
        else {
            return nil
        }

        return StoredFile(
            id: sqlite3_column_int64(statement, 0),
            path: path,
            filename: filename,
            ext: ext,
            size: sqlite3_column_int64(statement, 4),
            modifiedDate: modifiedDate
        )
    }

    private enum Binding {
        case text(String)
        case int(Int64)
    }

    private func bind(_ bindings: [Binding], to statement: OpaquePointer) throws {
        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch binding {
            case .text(let value):
                result = bindText(value, to: statement, at: position)
            case .int(let value):
                result = sqlite3_bind_int64(statement, position, value)
            }
            guard result == SQLITE_OK else {
                throw ProjectMindError.databaseQueryFailed(underlying: lastErrorMessage())
            }
        }
    }

    private func bindText(_ value: String, to statement: OpaquePointer, at index: Int32) -> Int32 {
        value.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, Self.transientDestructor)
        }
    }

    private func columnText(_ statement: OpaquePointer, index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    private func lastErrorMessage() -> String {
        String(cString: sqlite3_errmsg(connection))
    }

    private static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
