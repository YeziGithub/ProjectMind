import Core
import Foundation

public struct GitModule: GitProtocol, Sendable {
    public init() {}

    public func inspect(at url: URL) async throws -> GitMetadata {
        throw ProjectMindError.notImplemented(module: "Git")
    }
}
