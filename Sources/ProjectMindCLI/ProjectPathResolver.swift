import Core
import Foundation
import Scanner

enum ProjectPathError: Error, Equatable, CustomStringConvertible {
    case invalidProjectPath(String)

    var description: String {
        switch self {
        case .invalidProjectPath(let path):
            "invalid project path: \(path)"
        }
    }
}

struct ProjectPathResolver {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func projectURL(from path: String) throws -> URL {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ProjectPathError.invalidProjectPath(url.path)
        }
        return url
    }

    func databaseURL(for projectURL: URL, databasePath: String?) -> URL {
        if let databasePath {
            return URL(fileURLWithPath: databasePath).standardizedFileURL
        }

        return projectURL
            .appendingPathComponent(".projectmind", isDirectory: true)
            .appendingPathComponent("projectmind.sqlite")
            .standardizedFileURL
    }

    func scannerConfiguration() -> ScannerConfiguration {
        let configuration = ScannerConfiguration.default
        return ScannerConfiguration(
            excludedDirectoryNames: configuration.excludedDirectoryNames.union([".projectmind"]),
            followSymlinks: configuration.followSymlinks
        )
    }

    func projectKind(for projectURL: URL) -> ProjectKind {
        if fileManager.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path) {
            return .swiftPackage
        }
        return .plainDirectory
    }
}
