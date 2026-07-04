import Foundation

/// An import statement extracted from a source file.
public struct ImportReference: Sendable, Equatable, Identifiable {
    public let id: String
    public let moduleName: String
    public let filePath: String
    public let location: SourceLocation?

    public init(
        id: String,
        moduleName: String,
        filePath: String,
        location: SourceLocation? = nil
    ) {
        self.id = id
        self.moduleName = moduleName
        self.filePath = filePath
        self.location = location
    }
}
