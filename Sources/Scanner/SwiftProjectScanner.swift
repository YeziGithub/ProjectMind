import Core
import Foundation

/// Streams files from a Swift project directory tree.
public struct SwiftProjectScanner: ScannerProtocol, Sendable {
  private let configuration: ScannerConfiguration

  public init(
    configuration: ScannerConfiguration = .default
  ) {
    self.configuration = configuration
  }

  public func scan(at url: URL) -> ProjectFileSequence {
    ProjectFileSequence(
      root: url,
      configuration: configuration
    )
  }
}
