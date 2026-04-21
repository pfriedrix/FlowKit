// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

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
            ]
        ),
        .testTarget(
            name: "FlowKitTests",
            dependencies: [
                "FlowKit"
            ]
        ),
        .macro(
            name: "FlowMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
