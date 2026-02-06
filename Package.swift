// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3")
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
      ]
    ),
    .target(
      name: "StreamingLZMAXZ",
      dependencies: ["Clzma"],
      resources: [
        .process("Resources")
      ]
    ),
    .executableTarget(
      name: "lzma-tool",
      dependencies: [
        "StreamingLZMA",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]
    ),
    .executableTarget(
      name: "xz-tool",
      dependencies: [
        "StreamingLZMAXZ",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]
    ),
    .testTarget(
      name: "StreamingLZMATests",
      dependencies: ["StreamingLZMA"],
      resources: [
        .copy("Fixtures")
      ]
    ),
    .testTarget(
      name: "StreamingLZMAXZTests",
      dependencies: ["StreamingLZMAXZ"]
    )
  ]
)
