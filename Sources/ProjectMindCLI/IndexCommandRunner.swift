import Core
import Database
import Foundation
import Parser
import Scanner

struct IndexResult: Equatable {
    let projectPath: String
    let databasePath: String
    let scannedFileCount: Int
    let indexedFileCount: Int
    let parsedSwiftFileCount: Int
    let symbolCount: Int
    let importCount: Int
    let elapsedSeconds: Double
}

enum IndexCommandError: Error, Equatable, CustomStringConvertible {
    case invalidProjectPath(String)

    var description: String {
        switch self {
        case .invalidProjectPath(let path):
            "invalid project path: \(path)"
        }
    }
}

struct IndexCommandRunner {
    private let pathResolver: ProjectPathResolver

    init(fileManager: FileManager = .default) {
        pathResolver = ProjectPathResolver(fileManager: fileManager)
    }

    func run(options: IndexCommandOptions) async throws -> IndexResult {
        let startedAt = Date()
        let projectURL: URL
        do {
            projectURL = try pathResolver.projectURL(from: options.projectPath)
        } catch ProjectPathError.invalidProjectPath(let path) {
            throw IndexCommandError.invalidProjectPath(path)
        }

        let databaseURL = pathResolver.databaseURL(for: projectURL, databasePath: options.databasePath)
        let scanner = SwiftProjectScanner(configuration: pathResolver.scannerConfiguration())
        let parser = SwiftSyntaxParser()
        let database = SQLiteDatabase()

        var scannedFileCount = 0
        var indexedFileCount = 0
        var parsedSwiftFileCount = 0
        var symbolCount = 0
        var importCount = 0

        do {
            try await database.open(at: databaseURL)
            try await database.createTables()

            for try await file in scanner.scan(at: projectURL) {
                scannedFileCount += 1
                try await database.upsertFile(file)
                indexedFileCount += 1

                guard file.ext == "swift" else { continue }
                let sourceFile = try await parser.parse(file: file)
                try await database.upsertSourceFile(sourceFile)
                parsedSwiftFileCount += 1
                symbolCount += sourceFile.symbols.count
                importCount += sourceFile.imports.count
            }

            try await database.close()
        } catch {
            try? await database.close()
            throw error
        }

        return IndexResult(
            projectPath: projectURL.path,
            databasePath: databaseURL.path,
            scannedFileCount: scannedFileCount,
            indexedFileCount: indexedFileCount,
            parsedSwiftFileCount: parsedSwiftFileCount,
            symbolCount: symbolCount,
            importCount: importCount,
            elapsedSeconds: Date().timeIntervalSince(startedAt)
        )
    }
}
