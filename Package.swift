// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectMind",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "projectmind", targets: ["ProjectMindCLI"]),
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Common", targets: ["Common"]),
        .library(name: "Scanner", targets: ["Scanner"]),
        .library(name: "Parser", targets: ["Parser"]),
        .library(name: "Database", targets: ["Database"]),
        .library(name: "Git", targets: ["Git"]),
        .library(name: "Query", targets: ["Query"]),
    ],
    targets: [
        // Layer 0 — foundation (no inter-module dependencies)
        .target(
            name: "Common"
        ),
        .target(
            name: "Core"
        ),

        // Layer 1 — domain modules (depend only on Core + Common)
        .target(
            name: "Scanner",
            dependencies: ["Core", "Common"]
        ),
        .target(
            name: "Parser",
            dependencies: ["Core", "Common"]
        ),
        .target(
            name: "Database",
            dependencies: ["Core", "Common"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "Git",
            dependencies: ["Core", "Common"]
        ),

        // Layer 2 — query (depends on Database, not Scanner/Parser)
        .target(
            name: "Query",
            dependencies: ["Core", "Common"]
        ),

        // Layer 3 — CLI entry point (command parsing only)
        .executableTarget(
            name: "ProjectMindCLI",
            dependencies: ["Core", "Scanner", "Database"]
        ),

        // Tests
        .testTarget(name: "CommonTests", dependencies: ["Common"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(
            name: "ScannerTests",
            dependencies: ["Scanner"],
            exclude: ["Fixtures"]
        ),
        .testTarget(name: "ParserTests", dependencies: ["Parser"]),
        .testTarget(name: "DatabaseTests", dependencies: ["Database"]),
        .testTarget(name: "GitTests", dependencies: ["Git"]),
        .testTarget(name: "QueryTests", dependencies: ["Query"]),
        .testTarget(
            name: "ProjectMindCLITests",
            dependencies: ["ProjectMindCLI", "Core", "Database"]
        ),
    ]
)
