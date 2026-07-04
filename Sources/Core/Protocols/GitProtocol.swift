import Foundation

/// Extracts version-control metadata from a repository.
public protocol GitProtocol: Sendable {
    func inspect(at url: URL) async throws -> GitMetadata
}
