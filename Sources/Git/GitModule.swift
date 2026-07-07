import Core
import Foundation

public struct GitModule: GitProtocol, Sendable {
    public init() {}

    public func inspect(at url: URL) async throws -> GitMetadata {
        let root = try runGit(arguments: ["-C", url.path, "rev-parse", "--show-toplevel"]).trimmed
        guard !root.isEmpty else {
            throw ProjectMindError.projectNotFound(path: url.path)
        }

        let branch = try? runGit(arguments: ["-C", root, "branch", "--show-current"]).trimmed
        let commit = try? runGit(arguments: ["-C", root, "rev-parse", "HEAD"]).trimmed
        let status = try runGit(arguments: ["-C", root, "status", "--porcelain"]).trimmed

        return GitMetadata(
            rootPath: root,
            branch: branch?.isEmpty == true ? nil : branch,
            latestCommit: commit?.isEmpty == true ? nil : commit,
            isDirty: !status.isEmpty
        )
    }

    private func runGit(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
        } catch {
            throw ProjectMindError.scanFailed(path: "git", underlying: "\(error)")
        }
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: outputData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "git command failed"
            throw ProjectMindError.projectNotFound(path: message.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return text
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
