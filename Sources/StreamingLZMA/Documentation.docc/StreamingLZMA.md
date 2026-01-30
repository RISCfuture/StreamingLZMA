# ``StreamingLZMA``

A Swift library for streaming LZMA and XZ compression and decompression.

## Overview

StreamingLZMA provides efficient, memory-friendly compression and decompression using the LZMA algorithm. It supports both raw LZMA format and the XZ container format, with streaming APIs for processing large files without loading them entirely into memory.

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

### XZ Compression

- ``XZCompressor``
- ``XZDecompressor``
- ``XZError``

### Configuration

- ``LZMAConfiguration``
- ``XZConfiguration``
- ``XZConfiguration/Check``
