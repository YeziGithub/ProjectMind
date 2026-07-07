import Core
import Foundation
import SQLite3

/// Low-level SQLite execution helpers shared by database operations.
struct SQLiteExecutor {
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

    func upsertFile(_ file: ProjectFile) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, SQLStatements.upsertFile, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        guard bind(file, to: statement) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
    }

    func updateFile(id: Int64, file: ProjectFile) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, SQLStatements.updateFile, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        guard bind(file, to: statement) == SQLITE_OK,
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

    func upsertSourceFile(_ sourceFile: SourceFile, parserKind: ParserKind) throws {
        try upsertSourceFileRow(sourceFile, parserKind: parserKind)
        try deleteRows(sql: SQLStatements.deleteSourceFileSymbols, filePath: sourceFile.file.path)
        try deleteRows(sql: SQLStatements.deleteSourceFileImports, filePath: sourceFile.file.path)

        for symbol in sourceFile.symbols {
            try insertSourceSymbol(symbol)
        }
        for importReference in sourceFile.imports {
            try insertImportReference(importReference)
        }
    }

    func querySymbols(_ query: SymbolQuery) throws -> [SourceSymbol] {
        var sql = SQLStatements.selectSymbolsBase
        var bindings: [Binding] = []

        if let name = query.name {
            sql += " AND name LIKE ?"
            bindings.append(.text("%\(name)%"))
        }
        if let kind = query.kind {
            sql += " AND kind = ?"
            bindings.append(.text(kind.rawValue))
        }
        if let filePath = query.filePath {
            sql += " AND file_path = ?"
            bindings.append(.text(filePath))
        }

        sql += " ORDER BY file_path, line, column LIMIT ? OFFSET ?;"
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

        var results: [SourceSymbol] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let symbol = readSourceSymbol(from: statement) else {
                continue
            }
            results.append(symbol)
        }
        return results
    }

    func queryImports(filePath: String?) throws -> [ImportReference] {
        var sql = SQLStatements.selectImportsBase
        var bindings: [Binding] = []

        if let filePath {
            sql += " AND file_path = ?"
            bindings.append(.text(filePath))
        }

        sql += " ORDER BY file_path, line, column;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseQueryFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        var results: [ImportReference] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let importReference = readImportReference(from: statement) else {
                continue
            }
            results.append(importReference)
        }
        return results
    }

    func deleteSourceFile(filePath: String) throws {
        try deleteRows(sql: SQLStatements.deleteSourceFileSymbols, filePath: filePath)
        try deleteRows(sql: SQLStatements.deleteSourceFileImports, filePath: filePath)
        try deleteRows(sql: SQLStatements.deleteSourceFile, filePath: filePath)
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

    private func upsertSourceFileRow(_ sourceFile: SourceFile, parserKind: ParserKind) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, SQLStatements.upsertSourceFile, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let parsedAt = dateFormatter.string(from: .now)
        guard bindText(sourceFile.file.path, to: statement, at: 1) == SQLITE_OK,
              bindText(sourceFile.file.path, to: statement, at: 2) == SQLITE_OK,
              bindText(parserKind.rawValue, to: statement, at: 3) == SQLITE_OK,
              bindText(parsedAt, to: statement, at: 4) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
    }

    private func insertSourceSymbol(_ symbol: SourceSymbol) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, SQLStatements.insertSourceSymbol, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let location = symbol.location ?? SourceLocation(line: 0, column: 0, endLine: 0, endColumn: 0)
        guard bindText(symbol.id, to: statement, at: 1) == SQLITE_OK,
              bindText(symbol.name, to: statement, at: 2) == SQLITE_OK,
              bindText(symbol.kind.rawValue, to: statement, at: 3) == SQLITE_OK,
              bindText(symbol.filePath, to: statement, at: 4) == SQLITE_OK,
              sqlite3_bind_int64(statement, 5, Int64(location.line)) == SQLITE_OK,
              sqlite3_bind_int64(statement, 6, Int64(location.column)) == SQLITE_OK,
              sqlite3_bind_int64(statement, 7, Int64(location.endLine)) == SQLITE_OK,
              sqlite3_bind_int64(statement, 8, Int64(location.endColumn)) == SQLITE_OK,
              bindNullableText(symbol.accessLevel, to: statement, at: 9) == SQLITE_OK,
              bindNullableText(symbol.parentName, to: statement, at: 10) == SQLITE_OK,
              bindNullableText(symbol.signature, to: statement, at: 11) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
    }

    private func insertImportReference(_ importReference: ImportReference) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, SQLStatements.insertImportReference, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let location = importReference.location ?? SourceLocation(line: 0, column: 0, endLine: 0, endColumn: 0)
        guard bindText(importReference.id, to: statement, at: 1) == SQLITE_OK,
              bindText(importReference.moduleName, to: statement, at: 2) == SQLITE_OK,
              bindText(importReference.filePath, to: statement, at: 3) == SQLITE_OK,
              sqlite3_bind_int64(statement, 4, Int64(location.line)) == SQLITE_OK,
              sqlite3_bind_int64(statement, 5, Int64(location.column)) == SQLITE_OK,
              sqlite3_bind_int64(statement, 6, Int64(location.endLine)) == SQLITE_OK,
              sqlite3_bind_int64(statement, 7, Int64(location.endColumn)) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
    }

    private func deleteRows(sql: String, filePath: String) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        guard bindText(filePath, to: statement, at: 1) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw ProjectMindError.databaseExecuteFailed(underlying: lastErrorMessage())
        }
    }

    private func readSourceSymbol(from statement: OpaquePointer) -> SourceSymbol? {
        guard let id = columnText(statement, index: 0),
              let name = columnText(statement, index: 1),
              let kindText = columnText(statement, index: 2),
              let kind = SymbolKind(rawValue: kindText),
              let filePath = columnText(statement, index: 3)
        else {
            return nil
        }

        return SourceSymbol(
            id: id,
            name: name,
            kind: kind,
            filePath: filePath,
            location: SourceLocation(
                line: Int(sqlite3_column_int64(statement, 4)),
                column: Int(sqlite3_column_int64(statement, 5)),
                endLine: Int(sqlite3_column_int64(statement, 6)),
                endColumn: Int(sqlite3_column_int64(statement, 7))
            ),
            accessLevel: columnText(statement, index: 8),
            parentName: columnText(statement, index: 9),
            signature: columnText(statement, index: 10)
        )
    }

    private func readImportReference(from statement: OpaquePointer) -> ImportReference? {
        guard let id = columnText(statement, index: 0),
              let moduleName = columnText(statement, index: 1),
              let filePath = columnText(statement, index: 2)
        else {
            return nil
        }

        return ImportReference(
            id: id,
            moduleName: moduleName,
            filePath: filePath,
            location: SourceLocation(
                line: Int(sqlite3_column_int64(statement, 3)),
                column: Int(sqlite3_column_int64(statement, 4)),
                endLine: Int(sqlite3_column_int64(statement, 5)),
                endColumn: Int(sqlite3_column_int64(statement, 6))
            )
        )
    }

    private enum Binding {
        case text(String)
        case int(Int64)
    }

    @discardableResult
    private func bind(_ file: ProjectFile, to statement: OpaquePointer) -> Int32 {
        let modifiedDate = dateFormatter.string(from: file.modifiedDate)
        guard bindText(file.path, to: statement, at: 1) == SQLITE_OK,
              bindText(file.filename, to: statement, at: 2) == SQLITE_OK,
              bindText(file.ext, to: statement, at: 3) == SQLITE_OK,
              sqlite3_bind_int64(statement, 4, file.size) == SQLITE_OK,
              bindText(modifiedDate, to: statement, at: 5) == SQLITE_OK
        else {
            return SQLITE_ERROR
        }
        return SQLITE_OK
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

    private func bindNullableText(_ value: String?, to statement: OpaquePointer, at index: Int32) -> Int32 {
        guard let value else {
            return sqlite3_bind_null(statement, index)
        }
        return bindText(value, to: statement, at: index)
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
