import Foundation

/// Root metadata for an indexed Swift project.
public struct Project: Sendable, Equatable, Identifiable {
    public let id: String
    public let rootPath: String
    public let name: String
    public let kind: ProjectKind
    public let scannedAt: Date

    public init(
        id: String,
        rootPath: String,
        name: String,
        kind: ProjectKind,
        scannedAt: Date = .now
    ) {
        self.id = id
        self.rootPath = rootPath
        self.name = name
        self.kind = kind
        self.scannedAt = scannedAt
    }
}
