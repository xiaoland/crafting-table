// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacOSScout",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "codex-macos-scout", targets: ["MacOSScout"])
    ],
    targets: [
        .executableTarget(name: "MacOSScout")
    ]
)
