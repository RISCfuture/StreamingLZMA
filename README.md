# StreamingLZMA

[![Build & Test](https://github.com/RISCfuture/StreamingLZMA/actions/workflows/build.yml/badge.svg)](https://github.com/RISCfuture/StreamingLZMA/actions/workflows/build.yml)
[![Documentation](https://img.shields.io/badge/docs-DocC-blue)](https://riscfuture.github.io/StreamingLZMA/documentation/streaminglzma/)
![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange)
![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS%20%7C%20Linux-lightgrey)

A Swift library for streaming LZMA and XZ compression and decompression, built on top of liblzma.

## Features

- Streaming compression and decompression for memory-efficient processing
- Support for both raw LZMA and XZ container formats
- One-shot convenience methods for simple use cases
- FileHandle extensions for file-based operations
- AsyncSequence support for modern Swift concurrency
- Configurable compression levels and parameters
- Thread-safe and Sendable types

## Installation

### Swift Package Manager

Add StreamingLZMA to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/RISCfuture/StreamingLZMA.git", from: "1.0.0")
]
```

### System Requirements

StreamingLZMA requires the liblzma library to be installed on your system.

**macOS:**
```bash
brew install xz
```

**Ubuntu/Debian:**
```bash
apt-get install liblzma-dev
```

**Fedora/RHEL:**
```bash
dnf install xz-devel
```

## Quick Start

### One-Shot Compression

```swift
import StreamingLZMA

// Compress data
let compressed = try LZMACompressor.compress(originalData)

// Decompress data
let decompressed = try LZMADecompressor.decompress(compressed)
```

### Streaming Compression

```swift
let compressor = try LZMACompressor()

// Process data in chunks
for chunk in dataChunks {
    let compressed = try compressor.compress(chunk)
    outputStream.write(compressed)
}

// Finalize the stream
let final = try compressor.finish()
outputStream.write(final)
```

### FileHandle Operations

```swift
// Compress a file
let inputHandle = try FileHandle(forReadingFrom: inputURL)
let outputHandle = try FileHandle(forWritingTo: outputURL)
try inputHandle.compress(to: outputHandle)

// Decompress a file
try compressedHandle.decompress(to: decompressedHandle)
```

### AsyncSequence Integration

```swift
// Compress an async sequence of data chunks
let compressedStream = dataStream.lzmaCompressed()
for try await chunk in compressedStream {
    // Process compressed chunks
}

// Decompress an async sequence
let decompressedStream = compressedDataStream.lzmaDecompressed()
```

## API Overview

### LZMA Format

- `LZMACompressor` - Streaming LZMA compression
- `LZMADecompressor` - Streaming LZMA decompression
- `LZMAError` - LZMA-specific errors

### XZ Format

- `XZCompressor` - Streaming XZ compression with integrity checks
- `XZDecompressor` - Streaming XZ decompression
- `XZError` - XZ-specific errors

### Configuration

- `LZMAPreset` - Compression level presets (0-9)
- `XZCheck` - Integrity check types (CRC32, CRC64, SHA-256)

## CLI Tool

StreamingLZMA includes a command-line tool for compression and decompression:

```bash
# Compress a file
swift run lzma-tool compress input.txt -o output.lzma

# Decompress a file
swift run lzma-tool decompress output.lzma -o restored.txt

# Use XZ format
swift run lzma-tool compress input.txt -o output.xz --format xz

# Specify compression level
swift run lzma-tool compress input.txt -o output.lzma --level 9
```

## Documentation

Full API documentation is available at [riscfuture.github.io/StreamingLZMA](https://riscfuture.github.io/StreamingLZMA/documentation/streaminglzma/).

## License

StreamingLZMA is available under the MIT License. See [LICENSE.md](LICENSE.md) for details.
