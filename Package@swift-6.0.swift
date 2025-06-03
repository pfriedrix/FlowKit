// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "FlowKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "FlowKit",
            targets: ["FlowKit"]),
        .library(
              name: "FlowMacros",
              targets: ["FlowMacros"]
            ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", exact: "600.0.1")
    ],
    targets: [
        .target(
            name: "FlowKit"),
        .testTarget(
            name: "Tests",
            dependencies: [
                "FlowKit"
            ]
        ),
        .target(
            name: "FlowMacros",
            dependencies: [
                "FlowMacrosPlugin"
            ]
        ),
        .macro(
            name: "FlowMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
