import Core
import Database
import Foundation

struct ImportsCommandRunner {
    func run(options: ImportsCommandOptions) async throws -> [ImportReference] {
        let database = SQLiteDatabase()
        do {
            try await database.open(at: URL(fileURLWithPath: options.databasePath).standardizedFileURL)
            try await database.createTables()
            let imports = try await database.queryImports(filePath: options.filePath)
            try await database.close()
            return imports
        } catch {
            try? await database.close()
            throw error
        }
    }
}
