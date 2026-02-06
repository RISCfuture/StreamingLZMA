# ``StreamingLZMA``

A Swift library for streaming LZMA compression and decompression using Apple's Compression framework.

## Overview

StreamingLZMA provides efficient, memory-friendly LZMA compression and decompression using Apple's built-in Compression framework. It works on all Apple platforms (macOS, iOS, tvOS, watchOS, visionOS) without requiring any external dependencies.

For XZ container format support, see the `StreamingLZMAXZ` module, which requires the system `liblzma` library.

The library offers multiple APIs to suit different use cases:
- **One-shot methods** for simple compression of in-memory data
- **Streaming classes** for processing data incrementally
- **FileHandle extensions** for file-based operations
- **AsyncSequence support** for modern Swift concurrency

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:AdvancedUsage>

### LZMA Compression

- ``LZMACompressor``
- ``LZMADecompressor``
- ``LZMAError``

### Configuration

- ``LZMAConfiguration``
