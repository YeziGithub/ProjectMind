import Foundation

/// A source code location within a file.
public struct SourceLocation: Sendable, Equatable, Hashable {
    public let line: Int
    public let column: Int
    public let endLine: Int
    public let endColumn: Int

    public init(line: Int, column: Int, endLine: Int, endColumn: Int) {
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
}
