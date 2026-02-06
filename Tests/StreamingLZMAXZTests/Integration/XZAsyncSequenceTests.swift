import Foundation
import Testing
@testable import StreamingLZMAXZ

@Suite("XZ AsyncSequence Tests")
struct XZAsyncSequenceTests {
  // MARK: - AsyncSequence<Data> Tests

  @Test("AsyncSequence<Data> compression")
  func asyncSequenceDataCompression() async throws {
    let original = Data("Test data for async sequence compression.".utf8)

    let stream = AsyncStream<Data> { continuation in
      continuation.yield(original)
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.xzCompressed() {
      compressed.append(chunk)
    }

    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("AsyncSequence<Data> decompression")
  func asyncSequenceDataDecompression() async throws {
    let original = Data("Test data for async sequence decompression.".utf8)
    let compressed = try original.xzCompressed()

    let stream = AsyncStream<Data> { continuation in
      continuation.yield(compressed)
      continuation.finish()
    }

    var decompressed = Data()
    for try await chunk in stream.xzDecompressed() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  @Test("AsyncSequence<Data> with multiple chunks")
  func asyncSequenceDataMultipleChunks() async throws {
    let part1 = Data("First part ".utf8)
    let part2 = Data("Second part ".utf8)
    let part3 = Data("Third part".utf8)
    let original = part1 + part2 + part3

    let stream = AsyncStream<Data> { continuation in
      continuation.yield(part1)
      continuation.yield(part2)
      continuation.yield(part3)
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.xzCompressed() {
      compressed.append(chunk)
    }

    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - AsyncSequence<UInt8> Tests

  @Test("AsyncSequence<UInt8> compression")
  func asyncSequenceBytesCompression() async throws {
    let original = Data("Test data for byte sequence compression.".utf8)

    let stream = AsyncStream<UInt8> { continuation in
      for byte in original {
        continuation.yield(byte)
      }
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.xzCompressed() {
      compressed.append(chunk)
    }

    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("AsyncSequence<UInt8> decompression")
  func asyncSequenceBytesDecompression() async throws {
    let original = Data("Test data for byte sequence decompression.".utf8)
    let compressed = try original.xzCompressed()

    let stream = AsyncStream<UInt8> { continuation in
      for byte in compressed {
        continuation.yield(byte)
      }
      continuation.finish()
    }

    var decompressed = Data()
    for try await chunk in stream.xzDecompressed() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  // MARK: - Round-Trip Tests

  @Test("AsyncSequence<Data> round-trip")
  func asyncSequenceDataRoundTrip() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })

    // Compress
    let compressStream = AsyncStream<Data> { continuation in
      // Split into chunks
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
    for try await chunk in compressStream.xzCompressed() {
      compressed.append(chunk)
    }

    // Decompress
    let decompressStream = AsyncStream<Data> { continuation in
      continuation.yield(compressed)
      continuation.finish()
    }

    var decompressed = Data()
    for try await chunk in decompressStream.xzDecompressed() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  @Test("AsyncSequence<UInt8> round-trip")
  func asyncSequenceBytesRoundTrip() async throws {
    let original = Data("Round trip test for byte sequences.".utf8)

    // Compress
    let compressStream = AsyncStream<UInt8> { continuation in
      for byte in original {
        continuation.yield(byte)
      }
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in compressStream.xzCompressed() {
      compressed.append(chunk)
    }

    // Decompress
    let decompressStream = AsyncStream<UInt8> { continuation in
      for byte in compressed {
        continuation.yield(byte)
      }
      continuation.finish()
    }

    var decompressed = Data()
    for try await chunk in decompressStream.xzDecompressed() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  // MARK: - Configuration Tests

  @Test("AsyncSequence with compact configuration")
  func asyncSequenceCompactConfig() async throws {
    let original = Data("Test with compact configuration.".utf8)

    let stream = AsyncStream<Data> { continuation in
      continuation.yield(original)
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.xzCompressed(configuration: .compact) {
      compressed.append(chunk)
    }

    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("AsyncSequence with fast preset")
  func asyncSequenceFastPreset() async throws {
    let original = Data("Test with fast preset.".utf8)

    let stream = AsyncStream<Data> { continuation in
      continuation.yield(original)
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.xzCompressed(configuration: .fast) {
      compressed.append(chunk)
    }

    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Empty Data Tests

  @Test("AsyncSequence<Data> empty stream")
  func asyncSequenceEmptyStream() async throws {
    let stream = AsyncStream<Data> { continuation in
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.xzCompressed() {
      compressed.append(chunk)
    }

    // Empty input produces XZ stream with just header/footer
    #expect(!compressed.isEmpty)
  }

  @Test("AsyncSequence<Data> with empty chunks")
  func asyncSequenceEmptyChunks() async throws {
    let original = Data("Data with empty chunks.".utf8)

    let stream = AsyncStream<Data> { continuation in
      continuation.yield(Data())
      continuation.yield(original)
      continuation.yield(Data())
      continuation.finish()
    }

    var compressed = Data()
    for try await chunk in stream.xzCompressed() {
      compressed.append(chunk)
    }

    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }
}
