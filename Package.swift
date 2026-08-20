// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let approachableConcurrency: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances")
]

let package = Package(
  name: "StreamingLZMA",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
    .tvOS(.v15),
    .watchOS(.v8),
    .visionOS(.v1)
  ],
  products: [
    .library(
      name: "StreamingLZMA",
      targets: ["StreamingLZMA"]
    ),
    .library(
      name: "StreamingLZMAXZ",
      targets: ["StreamingLZMAXZ"]
    ),
    .executable(
      name: "lzma-tool",
      targets: ["lzma-tool"]
    ),
    .executable(
      name: "xz-tool",
      targets: ["xz-tool"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0")
  ],
  targets: [
    .systemLibrary(
      name: "Clzma",
      pkgConfig: "liblzma",
      providers: [.brew(["xz"])]
    ),
    .target(
      name: "StreamingLZMA",
      resources: [
        .process("Resources")
      ],
      swiftSettings: approachableConcurrency
    ),
    .target(
      name: "StreamingLZMAXZ",
      dependencies: ["Clzma"],
      resources: [
        .process("Resources")
      ],
      swiftSettings: approachableConcurrency
    ),
    .executableTarget(
      name: "lzma-tool",
      dependencies: [
        "StreamingLZMA",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      swiftSettings: approachableConcurrency
    ),
    .executableTarget(
      name: "xz-tool",
      dependencies: [
        "StreamingLZMAXZ",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      swiftSettings: approachableConcurrency
    ),
    .testTarget(
      name: "StreamingLZMATests",
      dependencies: ["StreamingLZMA"],
      resources: [
        .copy("Fixtures")
      ],
      swiftSettings: approachableConcurrency
    ),
    .testTarget(
      name: "StreamingLZMAXZTests",
      dependencies: ["StreamingLZMAXZ"],
      swiftSettings: approachableConcurrency
    )
  ]
)
