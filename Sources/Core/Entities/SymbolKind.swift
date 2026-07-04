import Foundation

/// Classification of symbols extracted from source code.
public enum SymbolKind: String, Sendable, Codable, Equatable, CaseIterable {
    case `import`
    case `class`
    case `struct`
    case `enum`
    case `protocol`
    case `function`
    case `property`
    case `typealias`
    case `variable`
    case `extension`
    case `actor`
    case `initializer`
    case `other`
}
