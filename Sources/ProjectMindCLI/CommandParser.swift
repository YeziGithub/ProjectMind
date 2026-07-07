import Foundation

enum CLICommand: Equatable {
    case scan(ScanCommandOptions)
    case index(IndexCommandOptions)
    case files(FilesCommandOptions)
    case symbols(SymbolsCommandOptions)
    case imports(ImportsCommandOptions)
    case git(GitCommandOptions)
    case context(ContextCommandOptions)
    case help
    case version
}

struct ScanCommandOptions: Equatable {
    let projectPath: String
    let databasePath: String?
}

struct IndexCommandOptions: Equatable {
    let projectPath: String
    let databasePath: String?
}

struct FilesCommandOptions: Equatable {
    let databasePath: String
    let ext: String?
    let path: String?
}

struct SymbolsCommandOptions: Equatable {
    let databasePath: String
    let name: String?
    let kind: String?
    let filePath: String?
}

struct ImportsCommandOptions: Equatable {
    let databasePath: String
    let filePath: String?
}

struct GitCommandOptions: Equatable {
    let projectPath: String
}

struct ContextCommandOptions: Equatable {
    let databasePath: String
    let query: String
}

enum CommandParserError: Error, Equatable, CustomStringConvertible {
    case missingPath(command: String)
    case missingRequiredOption(String)
    case unknownOption(String)
    case missingOptionValue(String)
    case invalidValue(option: String, value: String)

    var description: String {
        switch self {
        case .missingPath(let command):
            "missing path for '\(command)'"
        case .missingRequiredOption(let option):
            "missing required \(option)"
        case .unknownOption(let option):
            "unknown option: \(option)"
        case .missingOptionValue(let option):
            "missing value for \(option)"
        case .invalidValue(let option, let value):
            "invalid value for \(option): \(value)"
        }
    }
}

struct CommandParser {
    func parse(_ arguments: [String]) throws -> CLICommand {
        guard let first = arguments.first else { return .help }

        switch first {
        case "scan":
            return try parseScan(Array(arguments.dropFirst()))
        case "index":
            return try parseIndex(Array(arguments.dropFirst()))
        case "files":
            return try parseFiles(Array(arguments.dropFirst()))
        case "symbols":
            return try parseSymbols(Array(arguments.dropFirst()))
        case "imports":
            return try parseImports(Array(arguments.dropFirst()))
        case "git":
            return try parseGit(Array(arguments.dropFirst()))
        case "context":
            return try parseContext(Array(arguments.dropFirst()))
        case "version":
            return .version
        case "help":
            return .help
        default:
            throw CommandParserError.unknownOption(first)
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

    private func parseIndex(_ arguments: [String]) throws -> CLICommand {
        let parsed = try parsePathCommand(arguments, command: "index", allowsDatabase: true)
        return .index(IndexCommandOptions(projectPath: parsed.path, databasePath: parsed.databasePath))
    }

    private func parseGit(_ arguments: [String]) throws -> CLICommand {
        let parsed = try parsePathCommand(arguments, command: "git", allowsDatabase: false)
        return .git(GitCommandOptions(projectPath: parsed.path))
    }

    private func parseFiles(_ arguments: [String]) throws -> CLICommand {
        var databasePath: String?
        var ext: String?
        var path: String?
        var index = 0

        while index < arguments.count {
            let option = arguments[index]
            switch option {
            case "--db":
                databasePath = try optionValue(arguments, option: option, index: &index)
            case "--ext":
                ext = try optionValue(arguments, option: option, index: &index)
            case "--path":
                path = try optionValue(arguments, option: option, index: &index)
            default:
                throw CommandParserError.unknownOption(option)
            }
        }

        guard let databasePath else {
            throw CommandParserError.missingRequiredOption("--db")
        }
        return .files(FilesCommandOptions(databasePath: databasePath, ext: ext, path: path))
    }

    private func parseSymbols(_ arguments: [String]) throws -> CLICommand {
        var databasePath: String?
        var name: String?
        var kind: String?
        var filePath: String?
        var index = 0

        while index < arguments.count {
            let option = arguments[index]
            switch option {
            case "--db":
                databasePath = try optionValue(arguments, option: option, index: &index)
            case "--name":
                name = try optionValue(arguments, option: option, index: &index)
            case "--kind":
                kind = try optionValue(arguments, option: option, index: &index)
            case "--file":
                filePath = try optionValue(arguments, option: option, index: &index)
            default:
                throw CommandParserError.unknownOption(option)
            }
        }

        guard let databasePath else {
            throw CommandParserError.missingRequiredOption("--db")
        }
        return .symbols(SymbolsCommandOptions(
            databasePath: databasePath,
            name: name,
            kind: kind,
            filePath: filePath
        ))
    }

    private func parseImports(_ arguments: [String]) throws -> CLICommand {
        var databasePath: String?
        var filePath: String?
        var index = 0

        while index < arguments.count {
            let option = arguments[index]
            switch option {
            case "--db":
                databasePath = try optionValue(arguments, option: option, index: &index)
            case "--file":
                filePath = try optionValue(arguments, option: option, index: &index)
            default:
                throw CommandParserError.unknownOption(option)
            }
        }

        guard let databasePath else {
            throw CommandParserError.missingRequiredOption("--db")
        }
        return .imports(ImportsCommandOptions(databasePath: databasePath, filePath: filePath))
    }

    private func parseContext(_ arguments: [String]) throws -> CLICommand {
        var databasePath: String?
        var query: String?
        var index = 0

        while index < arguments.count {
            let option = arguments[index]
            switch option {
            case "--db":
                databasePath = try optionValue(arguments, option: option, index: &index)
            case "--query":
                query = try optionValue(arguments, option: option, index: &index)
            default:
                throw CommandParserError.unknownOption(option)
            }
        }

        guard let databasePath else {
            throw CommandParserError.missingRequiredOption("--db")
        }
        guard let query else {
            throw CommandParserError.missingRequiredOption("--query")
        }
        return .context(ContextCommandOptions(databasePath: databasePath, query: query))
    }

    private func parsePathCommand(
        _ arguments: [String],
        command: String,
        allowsDatabase: Bool
    ) throws -> (path: String, databasePath: String?) {
        var path: String?
        var databasePath: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--db", allowsDatabase {
                databasePath = try optionValue(arguments, option: argument, index: &index)
                continue
            }
            if argument.hasPrefix("--") {
                throw CommandParserError.unknownOption(argument)
            }
            guard path == nil else {
                throw CommandParserError.unknownOption(argument)
            }
            path = argument
            index += 1
        }

        guard let path else {
            throw CommandParserError.missingPath(command: command)
        }
        return (path, databasePath)
    }

    private func optionValue(_ arguments: [String], option: String, index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw CommandParserError.missingOptionValue(option)
        }
        let value = arguments[valueIndex]
        guard !value.hasPrefix("--") else {
            throw CommandParserError.missingOptionValue(option)
        }
        index += 2
        return value
    }
}
