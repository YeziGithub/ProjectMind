import Foundation

@main
struct ProjectMindCLI {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = CommandParser().parse(arguments)

        switch command {
        case .scan, .parse, .index, .query, .git:
            print("Command '\(command.rawValue)' is not yet implemented.")
        case .version:
            print("projectmind 0.1.0")
        case .help:
            printUsage()
        }
    }

    private static func printUsage() {
        print("""
        ProjectMind — AI Coding Infrastructure

        Usage:
          projectmind scan <path>
          projectmind parse <path>
          projectmind index <path>
          projectmind query <path>
          projectmind git <path>
          projectmind version
          projectmind help
        """)
    }
}
