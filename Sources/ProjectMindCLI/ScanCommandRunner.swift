import Core
import Database
import Foundation
import Scanner

struct ScanResult: Equatable {
    let projectPath: String
    let databasePath: String
    let scannedFileCount: Int
    let indexedFileCount: Int
    let elapsedSeconds: Double
}

enum ScanCommandError: Error, Equatable, CustomStringConvertible {
    case invalidProjectPath(String)

    var description: String {
        switch self {
        case .invalidProjectPath(let path):
            "invalid project path: \(path)"
        }
    }
}

struct ScanCommandRunner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func run(options: ScanCommandOptions) async throws -> ScanResult {
        let startedAt = Date()
        let projectURL = URL(fileURLWithPath: options.projectPath).standardizedFileURL
        try validateProjectPath(projectURL)

        let databaseURL = databaseURL(for: projectURL, databasePath: options.databasePath)
        _ = Project(
            id: projectURL.path,
            rootPath: projectURL.path,
            name: projectURL.lastPathComponent,
            kind: projectKind(for: projectURL)
        )

        var scannerConfiguration = ScannerConfiguration.default
        scannerConfiguration = ScannerConfiguration(
            excludedDirectoryNames: scannerConfiguration.excludedDirectoryNames.union([".projectmind"]),
            followSymlinks: scannerConfiguration.followSymlinks
        )
        let scanner = SwiftProjectScanner(configuration: scannerConfiguration)
        let database = SQLiteDatabase()

        var scannedFileCount = 0
        var indexedFileCount = 0

        do {
            try await database.open(at: databaseURL)
            try await database.createTables()

            for try await file in scanner.scan(at: projectURL) {
                scannedFileCount += 1
                try await database.upsertFile(file)
                indexedFileCount += 1
            }

            try await database.close()
        } catch {
            try? await database.close()
            throw error
        }

        return ScanResult(
            projectPath: projectURL.path,
            databasePath: databaseURL.path,
            scannedFileCount: scannedFileCount,
            indexedFileCount: indexedFileCount,
            elapsedSeconds: Date().timeIntervalSince(startedAt)
        )
    }

    private func validateProjectPath(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ScanCommandError.invalidProjectPath(url.path)
        }
    }

    private func databaseURL(for projectURL: URL, databasePath: String?) -> URL {
        if let databasePath {
            return URL(fileURLWithPath: databasePath).standardizedFileURL
        }

        return projectURL
            .appendingPathComponent(".projectmind", isDirectory: true)
            .appendingPathComponent("projectmind.sqlite")
            .standardizedFileURL
    }

    private func projectKind(for projectURL: URL) -> ProjectKind {
        if fileManager.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path) {
            return .swiftPackage
        }
        return .plainDirectory
    }
}
