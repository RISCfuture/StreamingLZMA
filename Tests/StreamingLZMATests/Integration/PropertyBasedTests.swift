import Testing
import Foundation
@testable import StreamingLZMA

@Suite("Property-Based Tests")
struct PropertyBasedTests {
  // MARK: - Round-Trip Invariant Tests

  @Test("Property: round-trip preserves data (sizes 1B to 1MB)")
  func roundTripPreservesData() throws {
    let sizes = [1, 10, 100, 1000, 10_000, 100_000, 1_000_000]

    for size in sizes {
      let original = Data((0..<size).map { UInt8($0 & 0xFF) })
      let compressed = try original.lzmaCompressed()
      let decompressed = try compressed.lzmaDecompressed()
      #expect(decompressed == original, "Round-trip failed at size \(size)")
    }
  }

  @Test("Property: round-trip with 20 random iterations")
  func roundTripRandomIterations() throws {
    for seed in UInt64(1)...20 {
      // Vary size based on seed
      let size = Int(seed * 500 + 100)
      let original = seededRandomData(count: size, seed: seed)

      let compressed = try original.lzmaCompressed()
      let decompressed = try compressed.lzmaDecompressed()

      #expect(decompressed == original, "Round-trip failed with seed \(seed)")
    }
  }

  // MARK: - Determinism Tests

  @Test("Property: compression is deterministic")
  func compressionIsDeterministic() throws {
    let original = Data("Determinism test data that should compress the same way every time.".utf8)

    let compressed1 = try original.lzmaCompressed()
    let compressed2 = try original.lzmaCompressed()
    let compressed3 = try original.lzmaCompressed()

    #expect(compressed1 == compressed2)
    #expect(compressed2 == compressed3)
  }

  @Test("Property: streaming compression is deterministic")
  func streamingCompressionIsDeterministic() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    // First streaming compression
    let compressor1 = try LZMACompressor()
    var result1 = try await compressor1.compress(original)
    result1.append(try await compressor1.finalize())

    // Second streaming compression
    let compressor2 = try LZMACompressor()
    var result2 = try await compressor2.compress(original)
    result2.append(try await compressor2.finalize())

    #expect(result1 == result2)
  }

  // MARK: - Streaming vs One-Shot Equivalence

  @Test("Property: streaming equals one-shot (single chunk)")
  func streamingEqualsOneShotSingleChunk() async throws {
    let original = Data("Streaming vs one-shot equivalence test.".utf8)

    // One-shot
    let oneShot = try original.lzmaCompressed()

    // Streaming (single chunk)
    let compressor = try LZMACompressor()
    var streaming = try await compressor.compress(original)
    streaming.append(try await compressor.finalize())

    #expect(streaming == oneShot)
  }

  @Test("Property: streaming produces decompressible output regardless of chunking")
  func streamingChunkingProducesValidOutput() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })

    // Different chunk sizes should all produce data that decompresses to the same result
    let chunkSizes = [1, 10, 100, 500, 1000, 5000, 10000]

    for chunkSize in chunkSizes {
      let compressed = try await compressInChunks(original, chunkSize: chunkSize)
      let decompressed = try compressed.lzmaDecompressed()
      #expect(decompressed == original, "Failed with chunk size \(chunkSize)")
    }
  }

  // MARK: - Chunk Size Independence

  @Test("Property: decompression is chunk-size independent")
  func decompressionChunkSizeIndependent() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    let decompressChunkSizes = [1, 10, 100, 500, 1000, 5000]

    for chunkSize in decompressChunkSizes {
      let decompressed = try await decompressInChunks(compressed, chunkSize: chunkSize)
      #expect(decompressed == original, "Failed with decompress chunk size \(chunkSize)")
    }
  }

  @Test("Property: compress chunk size doesn't affect decompressed result")
  func compressChunkSizeDoesntAffectResult() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    // Different compression chunk sizes
    for compressChunkSize in [1, 10, 100, 500, 1000, 5000] {
      let compressed = try await compressInChunks(original, chunkSize: compressChunkSize)

      // All should decompress to the same original
      let decompressed = try compressed.lzmaDecompressed()
      #expect(decompressed == original, "Failed with compress chunk size \(compressChunkSize)")
    }
  }

  // MARK: - Configuration Independence

  @Test("Property: different compress configs produce decompressible output")
  func differentCompressConfigs() throws {
    let original = Data((0..<20000).map { UInt8($0 & 0xFF) })
    let configs: [LZMAConfiguration] = [.compact, .default, .highThroughput]

    for compressConfig in configs {
      let compressed = try original.lzmaCompressed(configuration: compressConfig)

      // Should decompress with any config
      for decompressConfig in configs {
        let decompressed = try compressed.lzmaDecompressed(configuration: decompressConfig)
        #expect(
          decompressed == original,
          "Failed: compress(\(compressConfig.bufferSize)) -> decompress(\(decompressConfig.bufferSize))"
        )
      }
    }
  }

  @Test("Property: custom buffer sizes work correctly")
  func customBufferSizes() throws {
    let original = Data((0..<15000).map { UInt8($0 & 0xFF) })
    let customSizes = [1024, 4096, 8192, 32768, 131072]

    for size in customSizes {
      let config = LZMAConfiguration(bufferSize: .custom(size))
      let compressed = try original.lzmaCompressed(configuration: config)
      let decompressed = try compressed.lzmaDecompressed(configuration: config)
      #expect(decompressed == original, "Failed with custom buffer size \(size)")
    }
  }

  // MARK: - Compressor/Decompressor Reuse

  @Test("Property: compressor reuse after reset")
  func compressorReuseAfterReset() async throws {
    let data1 = Data("First data to compress.".utf8)
    let data2 = Data("Second data to compress after reset.".utf8)
    let data3 = Data("Third data to compress after another reset.".utf8)

    let compressor = try LZMACompressor()

    // First compression
    var compressed1 = try await compressor.compress(data1)
    compressed1.append(try await compressor.finalize())
    let decompressed1 = try compressed1.lzmaDecompressed()
    #expect(decompressed1 == data1)

    // Reset and second compression
    try await compressor.reset()
    var compressed2 = try await compressor.compress(data2)
    compressed2.append(try await compressor.finalize())
    let decompressed2 = try compressed2.lzmaDecompressed()
    #expect(decompressed2 == data2)

    // Reset and third compression
    try await compressor.reset()
    var compressed3 = try await compressor.compress(data3)
    compressed3.append(try await compressor.finalize())
    let decompressed3 = try compressed3.lzmaDecompressed()
    #expect(decompressed3 == data3)
  }

  @Test("Property: decompressor reuse after reset")
  func decompressorReuseAfterReset() async throws {
    let data1 = Data("First data".utf8)
    let data2 = Data("Second data after reset".utf8)

    let compressed1 = try data1.lzmaCompressed()
    let compressed2 = try data2.lzmaCompressed()

    let decompressor = try LZMADecompressor()

    // First decompression
    var result1 = try await decompressor.decompress(compressed1)
    result1.append(try await decompressor.finalize())
    #expect(result1 == data1)

    // Reset and second decompression
    try await decompressor.reset()
    var result2 = try await decompressor.decompress(compressed2)
    result2.append(try await decompressor.finalize())
    #expect(result2 == data2)
  }

  // MARK: - Composition Properties

  @Test("Property: concatenated data compresses correctly")
  func concatenatedDataCompresses() throws {
    let part1 = Data("First part of the data. ".utf8)
    let part2 = Data("Second part of the data. ".utf8)
    let part3 = Data("Third part of the data.".utf8)

    let combined = part1 + part2 + part3

    let compressed = try combined.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()

    #expect(decompressed == combined)
  }

  @Test("Property: repeated round-trips produce same result")
  func repeatedRoundTrips() throws {
    var current = Data("Data for repeated round-trip testing.".utf8)
    let original = current

    // Compress and decompress 5 times
    for _ in 0..<5 {
      current = try current.lzmaCompressed().lzmaDecompressed()
    }

    #expect(current == original)
  }

  // MARK: - Boundary Properties

  @Test("Property: data length preserved exactly")
  func dataLengthPreserved() throws {
    for length in [1, 2, 255, 256, 1023, 1024, 65535, 65536] {
      let original = seededRandomData(count: length, seed: UInt64(length))
      let decompressed = try original.lzmaCompressed().lzmaDecompressed()
      #expect(decompressed.count == original.count, "Length mismatch at \(length)")
      #expect(decompressed == original)
    }
  }

  @Test("Property: all byte values preserved in round-trip")
  func allByteValuesPreserved() throws {
    // Create data containing all possible byte values multiple times
    var data = Data()
    for _ in 0..<100 {
      data.append(contentsOf: UInt8.min...UInt8.max)
    }

    let decompressed = try data.lzmaCompressed().lzmaDecompressed()
    #expect(decompressed == data)
  }

  // MARK: - Idempotence Properties

  @Test("Property: decompression of already decompressed data fails")
  func decompressionNotIdempotent() throws {
    let original = Data("Test data".utf8)
    let decompressed = try original.lzmaCompressed().lzmaDecompressed()

    // Trying to decompress already decompressed data should fail
    #expect(throws: LZMAError.corruptedData) {
      try decompressed.lzmaDecompressed()
    }
  }
}
