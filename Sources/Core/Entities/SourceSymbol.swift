import Foundation

/// A named symbol extracted from source code.
public struct SourceSymbol: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let kind: SymbolKind
    public let filePath: String
    public let location: SourceLocation?
    public let accessLevel: String?
    public let parentName: String?
    public let signature: String?

    public init(
        id: String,
        name: String,
        kind: SymbolKind,
        filePath: String,
        location: SourceLocation? = nil,
        accessLevel: String? = nil,
        parentName: String? = nil,
        signature: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.filePath = filePath
        self.location = location
        self.accessLevel = accessLevel
        self.parentName = parentName
        self.signature = signature
    }
}
