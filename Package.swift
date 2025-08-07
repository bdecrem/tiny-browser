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
            sources: ["TinyBrowserApp.swift", "ContentView.swift", "WebView.swift", "BrowserModels.swift", "BookmarkModels.swift"],
            resources: [.process("Assets.xcassets")],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)