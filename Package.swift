// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let strictSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "FlowKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "FlowKit",
            targets: ["FlowKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", exact: "600.0.1")
    ],
    targets: [
        .target(
            name: "FlowKit",
            dependencies: [
                "FlowMacros"
            ],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "FlowKitTests",
            dependencies: [
                "FlowKit"
            ],
            swiftSettings: strictSettings
        ),
        .macro(
            name: "FlowMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            swiftSettings: strictSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
