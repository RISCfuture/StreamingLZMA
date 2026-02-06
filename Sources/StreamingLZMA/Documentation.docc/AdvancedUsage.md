# Advanced Usage

Explore streaming architecture, async integration, and performance optimization techniques.

## Overview

This guide covers advanced topics including the streaming architecture, AsyncSequence integration, performance tuning, and best practices for production use.

## Streaming Architecture

StreamingLZMA uses a stateful streaming design where compressor and decompressor instances maintain internal buffers and state across multiple calls.

### Compressor Lifecycle

1. **Initialize** - Create a compressor with desired settings
2. **Process** - Feed data chunks through `compress(_:)`
3. **Finalize** - Call `finish()` to flush remaining data and complete the stream

```swift
let compressor = try LZMACompressor(preset: .preset6)

// Each call returns compressed output (may be empty if buffered)
let part1 = try compressor.compress(chunk1)
let part2 = try compressor.compress(chunk2)

// finish() flushes all remaining data
let final = try compressor.finish()

// After finish(), the compressor cannot be reused
```

### Decompressor Behavior

Decompressors automatically detect stream boundaries and can handle concatenated streams:

```swift
let decompressor = try LZMADecompressor()

// Process compressed data in any chunk size
for chunk in compressedChunks {
    let decompressed = try decompressor.decompress(chunk)
    // Output may be larger or smaller than input
}
```

## AsyncSequence Integration

StreamingLZMA provides seamless integration with Swift's async sequences:

### Compressing Streams

```swift
func uploadCompressed(dataStream: AsyncStream<Data>) async throws {
    let compressedStream = dataStream.lzmaCompressed()

    for try await chunk in compressedStream {
        try await uploadChunk(chunk)
    }
}
```

### Decompressing Streams

```swift
func processDownload(compressedStream: AsyncStream<Data>) async throws {
    let decompressedStream = compressedStream.lzmaDecompressed()

    for try await chunk in decompressedStream {
        try await processData(chunk)
    }
}
```

### Chaining Operations

Combine with other async sequence operations:

```swift
let processedStream = rawDataStream
    .lzmaCompressed()
    .map { chunk in
        // Add framing or headers
        var framed = Data()
        framed.append(UInt32(chunk.count).littleEndianBytes)
        framed.append(chunk)
        return framed
    }
```

## Performance Tuning

### Choosing Compression Levels

| Preset | Speed | Ratio | Memory | Use Case |
|--------|-------|-------|--------|----------|
| 0-2 | Fast | Lower | ~1 MB | Real-time, streaming |
| 3-5 | Balanced | Medium | ~10 MB | General purpose |
| 6 | Default | Good | ~30 MB | Files, archives |
| 7-9 | Slow | Best | ~100+ MB | Archival storage |

```swift
// For real-time streaming
let fast = try LZMACompressor(preset: .preset1)

// For maximum compression
let max = try LZMACompressor(preset: .preset9)
```

### Buffer Sizing

When using streaming APIs, larger input chunks generally improve throughput:

```swift
// Better performance with larger chunks
let optimalChunkSize = 64 * 1024  // 64 KB
let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: optimalChunkSize, alignment: 1)
```

## Error Recovery

### Handling Corrupted Data

When decompressing potentially corrupted data, handle errors gracefully:

```swift
func decompressSafely(_ data: Data) -> Data? {
    do {
        return try LZMADecompressor.decompress(data)
    } catch LZMAError.corruptedData {
        // Data is damaged, cannot recover
        return nil
    } catch {
        // Other errors (memory, internal)
        throw error
    }
}
```

### Stream State Management

After an error, the stream is in an undefined state. Create a new instance:

```swift
var compressor = try LZMACompressor()

do {
    let result = try compressor.compress(data)
} catch {
    // Reset by creating new instance
    compressor = try LZMACompressor()
}
```

## Best Practices

### Memory Management

- Use streaming APIs for files larger than available memory
- Choose appropriate compression levels for memory constraints
- Release compressor/decompressor instances when done

### Thread Safety

All compressor and decompressor types are `Sendable` but not thread-safe for concurrent access. Use separate instances per thread or synchronize access:

```swift
// Safe: separate instances
let compressor1 = try LZMACompressor()
let compressor2 = try LZMACompressor()

// Use compressor1 on thread A
// Use compressor2 on thread B
```

### Resource Cleanup

Compressors allocate native resources. While Swift's ARC handles cleanup, explicitly finishing streams ensures all data is flushed:

```swift
let compressor = try LZMACompressor()
defer {
    // Ensure stream is finalized even on error
    _ = try? compressor.finish()
}

// Process data...
```
