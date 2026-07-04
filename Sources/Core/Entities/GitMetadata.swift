import Foundation

/// Version-control metadata for a repository.
public struct GitMetadata: Sendable, Equatable {
    public let rootPath: String
    public let branch: String?
    public let latestCommit: String?
    public let isDirty: Bool

    public init(
        rootPath: String,
        branch: String? = nil,
        latestCommit: String? = nil,
        isDirty: Bool = false
    ) {
        self.rootPath = rootPath
        self.branch = branch
        self.latestCommit = latestCommit
        self.isDirty = isDirty
    }
}
