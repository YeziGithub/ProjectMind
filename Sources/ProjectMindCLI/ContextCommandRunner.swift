import Core
import Database
import Foundation

struct ContextMatch: Equatable {
    let filePath: String
    let reason: String
}

struct ContextCommandRunner {
    func run(options: ContextCommandOptions) async throws -> [ContextMatch] {
        let database = SQLiteDatabase()
        let files: [StoredFile]
        let symbols: [SourceSymbol]
        do {
            try await database.open(at: URL(fileURLWithPath: options.databasePath).standardizedFileURL)
            try await database.createTables()
            files = try await database.query(FileQuery(limit: 10_000, offset: 0))
            symbols = try await database.querySymbols(SymbolQuery(
                name: options.query,
                limit: 10_000,
                offset: 0
            ))
            try await database.close()
        } catch {
            try? await database.close()
            throw error
        }

        var matches: [String: ContextMatch] = [:]
        for symbol in symbols {
            matches[symbol.filePath] = ContextMatch(
                filePath: symbol.filePath,
                reason: "symbol name matched \(options.query)"
            )
        }

        for file in files where matches[file.path] == nil {
            if file.filename.localizedCaseInsensitiveContains(options.query) {
                matches[file.path] = ContextMatch(
                    filePath: file.path,
                    reason: "filename matched \(options.query)"
                )
            } else if file.path.localizedCaseInsensitiveContains(options.query) {
                matches[file.path] = ContextMatch(
                    filePath: file.path,
                    reason: "file path matched \(options.query)"
                )
            }
        }

        return matches.values.sorted { $0.filePath < $1.filePath }
    }
}
