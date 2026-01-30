import Testing
import Foundation
@testable import StreamingLZMA

@Suite("AsyncSequence Extension Tests")
struct AsyncSequenceTests {
  // MARK: - Element == Data Tests

  @Test("AsyncSequence<Data> compression")
  func asyncSequenceDataCompression() async throws {
    let chunks = [
      Data("Hello, ".utf8),
      Data("async ".utf8),
      Data("sequence!".utf8)
    ]

    let stream = AsyncStream<Data> { continuation in
      for chunk in chunks {
        continuation.yield(chunk)
      }
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.lzmaCompressed() {
      compressed.append(chunk)
    }

    let original = chunks.reduce(Data()) { $0 + $1 }
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("AsyncSequence<Data> decompression")
  func asyncSequenceDataDecompression() async throws {
    let original = Data("Hello, async sequence decompression!".utf8)
    let compressed = try original.lzmaCompressed()

    // Split compressed data into chunks
    let chunkSize = compressed.count / 3 + 1
    var chunks: [Data] = []
    var offset = 0
    while offset < compressed.count {
      let end = min(offset + chunkSize, compressed.count)
      chunks.append(Data(compressed[offset..<end]))
      offset = end
    }

    let stream = AsyncStream<Data> { continuation in
      for chunk in chunks {
        continuation.yield(chunk)
      }
      continuation.finish()
    }

    var decompressed = Data()
    for try await chunk in stream.lzmaDecompressed() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  // MARK: - Element == UInt8 Tests

  @Test("AsyncSequence<UInt8> compression")
  func asyncSequenceByteCompression() async throws {
    let original = Data("Hello, byte stream!".utf8)

    let stream = AsyncStream<UInt8> { continuation in
      for byte in original {
        continuation.yield(byte)
      }
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.lzmaCompressed() {
      compressed.append(chunk)
    }

    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("AsyncSequence<UInt8> decompression")
  func asyncSequenceByteDecompression() async throws {
    let original = Data("Hello, byte decompression!".utf8)
    let compressed = try original.lzmaCompressed()

    let stream = AsyncStream<UInt8> { continuation in
      for byte in compressed {
        continuation.yield(byte)
      }
      continuation.finish()
    }

    var decompressed = Data()
    for try await chunk in stream.lzmaDecompressed() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  // MARK: - Configuration Tests

  @Test("AsyncSequence with custom configuration")
  func asyncSequenceCustomConfig() async throws {
    let original = Data("Custom config test".utf8)
    let config = LZMAConfiguration(bufferSize: .custom(1024))

    let stream = AsyncStream<Data> { continuation in
      continuation.yield(original)
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.lzmaCompressed(configuration: config) {
      compressed.append(chunk)
    }

    let decompressed = try compressed.lzmaDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  // MARK: - Round-Trip Tests

  @Test("Full async round-trip")
  func fullAsyncRoundTrip() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    // Compress
    let compressStream = AsyncStream<Data> { continuation in
      // Send in chunks
      let chunkSize = 1000
      var offset = 0
      while offset < original.count {
        let end = min(offset + chunkSize, original.count)
        continuation.yield(Data(original[offset..<end]))
        offset = end
      }
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in compressStream.lzmaCompressed() {
      compressed.append(chunk)
    }

    // Decompress
    let decompressStream = AsyncStream<Data> { continuation in
      continuation.yield(compressed)
      continuation.finish()
    }

    var decompressed = Data()
    for try await chunk in decompressStream.lzmaDecompressed() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }
}
