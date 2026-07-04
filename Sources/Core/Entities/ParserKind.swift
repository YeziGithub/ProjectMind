import Foundation

/// Identifies the underlying parsing engine implementation.
public enum ParserKind: String, Sendable, Codable, CaseIterable {
    case treeSitter
    case sourceKit
    case swiftSyntax
}
