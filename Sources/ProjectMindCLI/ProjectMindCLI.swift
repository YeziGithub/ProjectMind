import Core
import Darwin
import Foundation

@main
struct ProjectMindCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())

        do {
            let command = try CommandParser().parse(arguments)
            try await run(command)
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }

    private static func run(_ command: CLICommand) async throws {
        switch command {
        case .scan(let options):
            let result = try await ScanCommandRunner().run(options: options)
            printScanResult(result)
        case .index(let options):
            let result = try await IndexCommandRunner().run(options: options)
            printIndexResult(result)
        case .files(let options):
            let files = try await FilesCommandRunner().run(options: options)
            printFiles(files)
        case .symbols(let options):
            let symbols = try await SymbolsCommandRunner().run(options: options)
            printSymbols(symbols)
        case .imports(let options):
            let imports = try await ImportsCommandRunner().run(options: options)
            printImports(imports)
        case .git(let options):
            let metadata = try await GitCommandRunner().run(options: options)
            printGitMetadata(metadata)
        case .context(let options):
            let matches = try await ContextCommandRunner().run(options: options)
            printContext(matches)
        case .version:
            print("projectmind 0.1.0")
        case .help:
            printUsage()
        }
    }

    private static func printScanResult(_ result: ScanResult) {
        print("""
        ProjectMind scan complete
        project: \(result.projectPath)
        scanned files: \(result.scannedFileCount)
        indexed files: \(result.indexedFileCount)
        database: \(result.databasePath)
        elapsed: \(String(format: "%.2f", result.elapsedSeconds))s
        """)
    }

    private static func printIndexResult(_ result: IndexResult) {
        print("""
        ProjectMind index complete
        project: \(result.projectPath)
        scanned files: \(result.scannedFileCount)
        indexed files: \(result.indexedFileCount)
        parsed swift files: \(result.parsedSwiftFileCount)
        symbols: \(result.symbolCount)
        imports: \(result.importCount)
        database: \(result.databasePath)
        elapsed: \(String(format: "%.2f", result.elapsedSeconds))s
        """)
    }

    private static func printFiles(_ files: [StoredFile]) {
        for file in files {
            print("\(file.path)\t\(file.filename)\t\(file.ext)\t\(file.size)")
        }
    }

    private static func printSymbols(_ symbols: [SourceSymbol]) {
        for symbol in symbols {
            let line = symbol.location?.line ?? 0
            if let signature = symbol.signature {
                print("\(symbol.kind.rawValue)\t\(symbol.name)\t\(symbol.filePath):\(line)\t\(signature)")
            } else {
                print("\(symbol.kind.rawValue)\t\(symbol.name)\t\(symbol.filePath):\(line)")
            }
        }
    }

    private static func printImports(_ imports: [ImportReference]) {
        for importReference in imports {
            let line = importReference.location?.line ?? 0
            print("\(importReference.moduleName)\t\(importReference.filePath):\(line)")
        }
    }

    private static func printGitMetadata(_ metadata: GitMetadata) {
        print("""
        git root: \(metadata.rootPath)
        branch: \(metadata.branch ?? "")
        latest commit: \(metadata.latestCommit ?? "")
        dirty: \(metadata.isDirty)
        """)
    }

    private static func printContext(_ matches: [ContextMatch]) {
        print("Relevant files:")
        for (index, match) in matches.enumerated() {
            print("\(index + 1). \(match.filePath)")
            print("   reason: \(match.reason)")
        }
    }

    private static func printUsage() {
        print("""
        ProjectMind — AI Coding Infrastructure

        Usage:
          projectmind scan <path> [--db <path>]
          projectmind index <path> [--db <path>]
          projectmind files --db <path> [--ext swift] [--path Sources]
          projectmind symbols --db <path> [--name User] [--kind struct] [--file path]
          projectmind imports --db <path> [--file path]
          projectmind git <path>
          projectmind context --db <path> --query <text>
          projectmind version
          projectmind help
        """)
    }
}
