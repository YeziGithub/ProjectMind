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
        case .parse, .index, .query, .git:
            print("Command is not yet implemented.")
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

    private static func printUsage() {
        print("""
        ProjectMind — AI Coding Infrastructure

        Usage:
          projectmind scan <path> [--db <path>]
          projectmind parse <path>
          projectmind index <path>
          projectmind query <path>
          projectmind git <path>
          projectmind version
          projectmind help
        """)
    }
}
