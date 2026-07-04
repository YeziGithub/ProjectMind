// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SamplePackage",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SamplePackage", targets: ["SamplePackage"]),
    ],
    targets: [
        .target(name: "SamplePackage"),
    ]
)
