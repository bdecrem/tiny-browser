// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TinyBrowser",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TinyBrowser", targets: ["TinyBrowser"])
    ],
    targets: [
        .executableTarget(
            name: "TinyBrowser",
            path: ".",
            sources: ["main.swift"]
        )
    ]
)