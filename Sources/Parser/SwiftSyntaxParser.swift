import Core

/// SwiftSyntax parser facade backed by the current lightweight parser.
public struct SwiftSyntaxParser: ParserProtocol, Sendable {
    private let parser = LightweightSwiftParser()

    public init() {}

    public var kind: ParserKind {
        parser.kind
    }

    public func parse(file: ProjectFile) async throws -> SourceFile {
        try await parser.parse(file: file)
    }
}
