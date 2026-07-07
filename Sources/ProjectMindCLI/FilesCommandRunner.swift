import Core
import Database
import Foundation

struct FilesCommandRunner {
    func run(options: FilesCommandOptions) async throws -> [StoredFile] {
        let database = SQLiteDatabase()
        let files: [StoredFile]
        do {
            try await database.open(at: URL(fileURLWithPath: options.databasePath).standardizedFileURL)
            try await database.createTables()
            files = try await database.query(FileQuery(ext: options.ext, limit: 10_000, offset: 0))
            try await database.close()
        } catch {
            try? await database.close()
            throw error
        }

        guard let path = options.path else {
            return files
        }
        return files.filter { $0.path.contains(path) }
    }
}
