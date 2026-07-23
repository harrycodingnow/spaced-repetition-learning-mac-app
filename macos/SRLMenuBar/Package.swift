// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SRLMenuBar",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "SRLMenuBar", targets: ["SRLMenuBar"]),
    ],
    targets: [
        .executableTarget(
            name: "SRLMenuBar",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "SRLMenuBarTests",
            dependencies: ["SRLMenuBar"]
        ),
    ]
)
