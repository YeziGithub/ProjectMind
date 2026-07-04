import Foundation

/// Discovers files within a Swift project directory via streaming iteration.
public protocol ScannerProtocol: Sendable {
    associatedtype Files: AsyncSequence & Sendable where Files.Element == ProjectFile

    /// Returns a lazy async sequence of project files. Results are not buffered in memory.
    func scan(at url: URL) -> Files
}
