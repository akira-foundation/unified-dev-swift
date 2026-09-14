// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UnifiedDev",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "UnifiedDev", targets: ["UnifiedDev"]),
        .executable(name: "bridge", targets: ["bridge"]),
        .executable(name: "sleep-helper", targets: ["sleep-helper"]),
        .library(name: "Core", targets: ["Core"]),
    ],
    dependencies: [
        // Native live Markdown editing for workspace notes. Pin the pre-1.0 API we integrate.
        .package(url: "https://github.com/nodes-app/swift-markdown-engine", exact: "0.12.0"),
        // The terminal panes. The upper bound is not tidiness: SwiftTerm tags 1.20.0 as a
        // pre-release ("one last before 2.0"), and SwiftPM cannot see that flag because the tag
        // carries no semver pre-release identifier, so a bare `from:` would resolve to it. 1.19.0
        // is what upstream marks as the release, and what upstream says comes next is 2.0 with
        // breaking changes, which this range would have to be opened by hand for anyway.
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", "1.19.0" ..< "1.20.0"),
        // The updater. Sparkle ships as a binary XCFramework, so `swift build` links the app
        // against it but copies nothing: `Tools/build.sh` embeds `Sparkle.framework` into
        // `Contents/Frameworks` and adds the rpath that finds it there. See `Tools/build.sh`.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6"),
    ],
    targets: [
        .target(
            name: "Core",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "UnifiedDev",
            dependencies: [
                "Core",
                .product(name: "MarkdownEngine", package: "swift-markdown-engine"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // The MCP stdio shim an agent CLI launches, which forwards to the running app over a unix
        // domain socket. Its own file is three lines: `Tools/test-core.sh` mirrors only Core and
        // its tests into the package it runs, so an executable target is invisible to the suite
        // and everything worth testing lives in `BridgeShim` instead.
        .executableTarget(
            name: "bridge",
            dependencies: ["Core"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // The privileged daemon that turns the system sleep switch off for a Keep Awake session,
        // which is the only way to hold a Mac open with the lid shut. No dependencies on purpose:
        // it runs as root, so the less of the app is inside it the better. See its own file.
        .executableTarget(
            name: "sleep-helper",
            path: "Sources/sleep-helper",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
