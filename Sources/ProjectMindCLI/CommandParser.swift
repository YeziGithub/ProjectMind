import Foundation

enum CLICommand: Equatable {
    case scan(ScanCommandOptions)
    case parse
    case index
    case query
    case git
    case help
    case version
}

struct ScanCommandOptions: Equatable {
    let projectPath: String
    let databasePath: String?
}

enum CommandParserError: Error, Equatable, CustomStringConvertible {
    case missingPath(command: String)
    case unknownOption(String)
    case missingOptionValue(String)

    var description: String {
        switch self {
        case .missingPath(let command):
            "missing path for '\(command)'"
        case .unknownOption(let option):
            "unknown option: \(option)"
        case .missingOptionValue(let option):
            "missing value for \(option)"
        }
    }
}

struct CommandParser {
    func parse(_ arguments: [String]) throws -> CLICommand {
        guard let first = arguments.first else { return .help }

        switch first {
        case "scan":
            return try parseScan(Array(arguments.dropFirst()))
        case "parse":
            return .parse
        case "index":
            return .index
        case "query":
            return .query
        case "git":
            return .git
        case "version":
            return .version
        case "help":
            return .help
        default:
            return .help
        }
    }

    private func parseScan(_ arguments: [String]) throws -> CLICommand {
        var projectPath: String?
        var databasePath: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            if argument == "--db" {
                let valueIndex = index + 1
                guard valueIndex < arguments.count else {
                    throw CommandParserError.missingOptionValue("--db")
                }
                databasePath = arguments[valueIndex]
                index += 2
                continue
            }

            if argument.hasPrefix("--") {
                throw CommandParserError.unknownOption(argument)
            }

            guard projectPath == nil else {
                throw CommandParserError.unknownOption(argument)
            }
            projectPath = argument
            index += 1
        }

        guard let projectPath else {
            throw CommandParserError.missingPath(command: "scan")
        }

        return .scan(ScanCommandOptions(projectPath: projectPath, databasePath: databasePath))
    }
}
