import Foundation

enum CLICommand: String {
    case scan
    case parse
    case index
    case query
    case git
    case help
    case version
}

struct CommandParser {
    func parse(_ arguments: [String]) -> CLICommand {
        guard let first = arguments.first else { return .help }
        return CLICommand(rawValue: first) ?? .help
    }
}
