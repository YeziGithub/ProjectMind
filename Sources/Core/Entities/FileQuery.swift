import Foundation

/// Query criteria for searching stored project files.
public struct FileQuery: Sendable, Equatable {
    public let path: String?
    public let filename: String?
    public let ext: String?
    public let limit: Int
    public let offset: Int

    public init(
        path: String? = nil,
        filename: String? = nil,
        ext: String? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.path = path
        self.filename = filename
        self.ext = ext
        self.limit = limit
        self.offset = offset
    }
}
