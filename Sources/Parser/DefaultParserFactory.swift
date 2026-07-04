import Core
import Foundation

/// Creates parser implementations for a given engine kind.
public struct DefaultParserFactory: Sendable {
    public init() {}

    public func makeParser(kind: ParserKind) -> any ParserProtocol {
        switch kind {
        case .treeSitter:
            TreeSitterParser()
        case .sourceKit:
            SourceKitParser()
        case .swiftSyntax:
            SwiftSyntaxParser()
        }
    }
}
