// swift-tools-version: 5.10

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "FlowKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "FlowKit",
            targets: ["FlowKit"]),
        .library(
              name: "Macros",
              targets: ["Macros"]
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
            name: "Macros",
            dependencies: [
                "MacrosPlugin"
            ]
        ),
        .macro(
            name: "MacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
    ],
)
