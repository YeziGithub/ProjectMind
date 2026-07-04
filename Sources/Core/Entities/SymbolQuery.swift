import Foundation

/// Query criteria for searching indexed symbols.
public struct SymbolQuery: Sendable, Equatable {
    public let name: String?
    public let kind: SymbolKind?
    public let filePath: String?
    public let limit: Int
    public let offset: Int

    public init(
        name: String? = nil,
        kind: SymbolKind? = nil,
        filePath: String? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.name = name
        self.kind = kind
        self.filePath = filePath
        self.limit = limit
        self.offset = offset
    }
}
