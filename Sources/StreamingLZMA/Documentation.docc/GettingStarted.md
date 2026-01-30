# Getting Started

Learn how to install and use StreamingLZMA for compression and decompression tasks.

## Overview

This guide covers installation, basic usage patterns, and common compression scenarios with StreamingLZMA.

## Installation

### Swift Package Manager

Add StreamingLZMA to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/RISCfuture/StreamingLZMA.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["StreamingLZMA"]
)
```

### System Requirements

StreamingLZMA requires the liblzma library. Install it for your platform:

**macOS:**
```bash
brew install xz
```

**Ubuntu/Debian:**
```bash
apt-get install liblzma-dev
```

## Basic Compression

The simplest way to compress data is using the one-shot class methods:

```swift
import StreamingLZMA

// Compress data
let originalData: Data = ...
let compressed = try LZMACompressor.compress(originalData)

// Decompress data
let decompressed = try LZMADecompressor.decompress(compressed)
```

## XZ Format

For better compatibility and integrity checking, use the XZ container format:

```swift
// Compress with XZ format
let compressed = try XZCompressor.compress(originalData)

// Decompress XZ data
let decompressed = try XZDecompressor.decompress(compressed)
```

## Streaming Compression

For large files or when memory is constrained, use the streaming API:

```swift
let compressor = try LZMACompressor()

// Process data incrementally
while let chunk = readNextChunk() {
    let compressed = try compressor.compress(chunk)
    writeOutput(compressed)
}

// Finalize and get remaining data
let finalData = try compressor.finish()
writeOutput(finalData)
```

Similarly for decompression:

```swift
let decompressor = try LZMADecompressor()

while let chunk = readNextCompressedChunk() {
    let decompressed = try decompressor.decompress(chunk)
    writeOutput(decompressed)
}
```

## File Operations

FileHandle extensions provide convenient file-based compression:

```swift
let inputHandle = try FileHandle(forReadingFrom: inputURL)
let outputHandle = try FileHandle(forWritingTo: outputURL)

// Compress entire file
try inputHandle.compress(to: outputHandle)
```

## Configuration

Customize compression with presets:

```swift
// Use maximum compression (slower but smaller)
let compressor = try LZMACompressor(preset: .preset9)

// Use fast compression (faster but larger)
let fastCompressor = try LZMACompressor(preset: .preset1)
```

For XZ format, specify integrity check type:

```swift
let compressor = try XZCompressor(preset: .preset6, check: .sha256)
```

## Error Handling

Handle compression errors appropriately:

```swift
do {
    let compressed = try LZMACompressor.compress(data)
} catch let error as LZMAError {
    switch error {
    case .emptyInput:
        print("No data to compress")
    case .corruptedData:
        print("Input data is invalid")
    default:
        print("Compression failed: \(error)")
    }
}
```
