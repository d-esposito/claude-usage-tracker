// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClaudeUsageTrackerDesktop",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ClaudeUsageTrackerDesktop", targets: ["ClaudeUsageTrackerDesktop"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeUsageTrackerDesktop",
            path: ".",
            exclude: [
                "assets", "DesktopTests", "README.md", "scripts", "DesktopApp/Info.plist"
            ],
            sources: ["DesktopApp", "Shared/UsageModels.swift"]
        ),
        .testTarget(
            name: "ClaudeUsageTrackerDesktopTests",
            dependencies: ["ClaudeUsageTrackerDesktop"],
            path: "DesktopTests"
        )
    ]
)
