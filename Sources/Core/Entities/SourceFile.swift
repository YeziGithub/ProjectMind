import Foundation

/// Structured parse result for a single source file.
public struct SourceFile: Sendable, Equatable {
    public let file: ProjectFile
    public let symbols: [SourceSymbol]
    public let imports: [ImportReference]

    public init(
        file: ProjectFile,
        symbols: [SourceSymbol] = [],
        imports: [ImportReference] = []
    ) {
        self.file = file
        self.symbols = symbols
        self.imports = imports
    }

    public var isEmpty: Bool {
        symbols.isEmpty && imports.isEmpty
    }

    public var declarationCount: Int {
        symbols.count + imports.count
    }

    public func symbols(ofKind kind: SymbolKind) -> [SourceSymbol] {
        symbols.filter { $0.kind == kind }
    }
}
