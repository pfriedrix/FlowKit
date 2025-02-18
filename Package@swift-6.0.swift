// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FlowKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "FlowKit",
            targets: ["FlowKit"]),
    ],
    targets: [
        .target(
            name: "FlowKit"),
        .testTarget(
            name: "Tests",
            dependencies: [
                "FlowKit"
            ]
        )
    ]
)
