// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UnifiedDev",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "UnifiedDev", targets: ["UnifiedDev"]),
        .executable(name: "bridge", targets: ["bridge"]),
        .executable(name: "preview", targets: ["preview"]),
        .executable(name: "sleep-helper", targets: ["sleep-helper"]),
        .library(name: "Core", targets: ["Core"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nodes-app/swift-markdown-engine", exact: "0.12.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", "1.19.0" ..< "1.20.0"),
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
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "bridge",
            dependencies: ["Core"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "preview",
            dependencies: ["Core"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
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
