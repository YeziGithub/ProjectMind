import Core
import Foundation
import Git

struct GitCommandRunner {
    func run(options: GitCommandOptions) async throws -> GitMetadata {
        try await GitModule().inspect(at: URL(fileURLWithPath: options.projectPath).standardizedFileURL)
    }
}
