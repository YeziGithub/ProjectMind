import Core
import Database
import Foundation

struct SymbolsCommandRunner {
    func run(options: SymbolsCommandOptions) async throws -> [SourceSymbol] {
        let kind: SymbolKind?
        if let rawKind = options.kind {
            guard let parsedKind = SymbolKind(rawValue: rawKind) else {
                throw CommandParserError.invalidValue(option: "--kind", value: rawKind)
            }
            kind = parsedKind
        } else {
            kind = nil
        }

        let database = SQLiteDatabase()
        do {
            try await database.open(at: URL(fileURLWithPath: options.databasePath).standardizedFileURL)
            try await database.createTables()
            let symbols = try await database.querySymbols(SymbolQuery(
                name: options.name,
                kind: kind,
                filePath: options.filePath,
                limit: 10_000,
                offset: 0
            ))
            try await database.close()
            return symbols
        } catch {
            try? await database.close()
            throw error
        }
    }
}
