// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "xomo-cli",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "xomo", targets: ["XomoCLI"])
    ],
    targets: [
        .executableTarget(
            name: "XomoCLI",
            path: "Sources/XomoCLI"
        ),
        .testTarget(
            name: "XomoCLITests",
            dependencies: ["XomoCLI"],
            path: "Tests/XomoCLITests"
        )
    ]
)
