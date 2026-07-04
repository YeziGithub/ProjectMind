import Foundation

/// Identifies the kind of Swift project.
public enum ProjectKind: String, Sendable, Codable, Equatable, CaseIterable {
    case swiftPackage
    case xcodeProject
    case plainDirectory
}
