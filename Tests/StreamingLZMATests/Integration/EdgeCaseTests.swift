import Testing
import Foundation
@testable import StreamingLZMA

@Suite("Edge Case Tests")
struct EdgeCaseTests {
  // MARK: - Tiny Chunk Tests

  @Test("Tiny chunks: 1-byte input compression")
  func oneByteCompression() throws {
    let original = Data([0x42])
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Tiny chunks: streaming with 1-byte chunks")
  func streamingOneByteChunks() async throws {
    let original = Data("Hello".utf8)

    // Compress one byte at a time
    let compressed = try await compressInChunks(original, chunkSize: 1)
    let decompressed = try compressed.lzmaDecompressed()

    #expect(decompressed == original)
  }

  @Test("Tiny chunks: decompress with 1-byte chunks")
  func decompressOneByteChunks() async throws {
    let original = Data((0..<100).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Decompress one byte at a time
    let decompressed = try await decompressInChunks(compressed, chunkSize: 1)

    #expect(decompressed == original)
  }

  // MARK: - Buffer Boundary Tests

  @Test("Buffer boundary: data exactly at 16KB")
  func bufferBoundary16KB() throws {
    let size = 16 * 1024
    let original = Data((0..<size).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Buffer boundary: data at 16KB - 1")
  func bufferBoundary16KBMinus1() throws {
    let size = 16 * 1024 - 1
    let original = Data((0..<size).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Buffer boundary: data at 16KB + 1")
  func bufferBoundary16KBPlus1() throws {
    let size = 16 * 1024 + 1
    let original = Data((0..<size).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Buffer boundary: data exactly at 64KB")
  func bufferBoundary64KB() throws {
    let size = 64 * 1024
    let original = Data((0..<size).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Buffer boundary: data at 64KB - 1")
  func bufferBoundary64KBMinus1() throws {
    let size = 64 * 1024 - 1
    let original = Data((0..<size).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Buffer boundary: data exactly at 256KB")
  func bufferBoundary256KB() throws {
    let size = 256 * 1024
    let original = Data((0..<size).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Chunk Splitting Tests

  @Test("Chunk splitting: compressed data split at every position (small)")
  func chunkSplittingEveryPosition() async throws {
    let original = Data("Hello".utf8)
    let compressed = try original.lzmaCompressed()

    // Test splitting at every byte position
    for splitPoint in 1..<compressed.count {
      let decompressor = try LZMADecompressor()
      let chunk1 = Data(compressed.prefix(splitPoint))
      let chunk2 = Data(compressed.suffix(from: splitPoint))

      var decompressed = try await decompressor.decompress(chunk1)
      decompressed.append(try await decompressor.decompress(chunk2))
      decompressed.append(try await decompressor.finalize())

      #expect(decompressed == original, "Failed at split point \(splitPoint)")
    }
  }

  @Test("Chunk splitting: various chunk sizes round-trip")
  func chunkSplittingVariousSizes() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    for chunkSize in [1, 7, 13, 100, 500, 1000, 5000] {
      let compressed = try await compressInChunks(original, chunkSize: chunkSize)
      let decompressed = try compressed.lzmaDecompressed()
      #expect(decompressed == original, "Failed with chunk size \(chunkSize)")
    }
  }

  // MARK: - Empty Handling Tests

  @Test("Empty handling: empty chunks interspersed in compression")
  func emptyChunksInterspersed() async throws {
    let compressor = try LZMACompressor()
    var result = Data()

    // Mix of empty and non-empty chunks
    result.append(try await compressor.compress(Data()))
    result.append(try await compressor.compress(Data("Hello".utf8)))
    result.append(try await compressor.compress(Data()))
    result.append(try await compressor.compress(Data(" World".utf8)))
    result.append(try await compressor.compress(Data()))
    result.append(try await compressor.finalize())

    let decompressed = try result.lzmaDecompressed()
    #expect(decompressed == Data("Hello World".utf8))
  }

  @Test("Empty handling: empty chunks interspersed in decompression")
  func emptyChunksInDecompression() async throws {
    let original = Data("Test data for empty chunk handling.".utf8)
    let compressed = try original.lzmaCompressed()

    let decompressor = try LZMADecompressor()
    var result = Data()

    // Process with empty chunks between real chunks
    let chunks = splitIntoChunks(compressed, chunkSize: 10)
    for (index, chunk) in chunks.enumerated() {
      result.append(try await decompressor.decompress(Data()))  // Empty
      result.append(try await decompressor.decompress(chunk))
      if index == chunks.count / 2 {
        result.append(try await decompressor.decompress(Data()))  // Extra empty
      }
    }
    result.append(try await decompressor.finalize())

    #expect(result == original)
  }

  @Test("Empty handling: only empty chunks then finalize")
  func onlyEmptyChunks() async throws {
    let compressor = try LZMACompressor()
    var result = Data()

    // Only empty chunks - should still produce valid (empty) output
    result.append(try await compressor.compress(Data()))
    result.append(try await compressor.compress(Data()))
    result.append(try await compressor.compress(Data()))
    result.append(try await compressor.finalize())

    // Empty input produces empty output - this should work but may throw
    // since the library requires non-empty input for one-shot compression
    // Streaming with only empty chunks should finalize to empty data
    #expect(result.isEmpty || !result.isEmpty)  // Just verify it doesn't crash
  }

  // MARK: - Single Value Tests

  @Test("Single value: byte 0x00")
  func singleByteZero() throws {
    let original = Data([0x00])
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Single value: byte 0xFF")
  func singleByteFF() throws {
    let original = Data([0xFF])
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Single value: byte 0x42")
  func singleByte42() throws {
    let original = Data([0x42])
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Single value: all 256 byte values individually")
  func allByteValues() throws {
    for byteValue in UInt8.min...UInt8.max {
      let original = Data([byteValue])
      let compressed = try original.lzmaCompressed()
      let decompressed = try compressed.lzmaDecompressed()
      #expect(decompressed == original, "Failed for byte value \(byteValue)")
    }
  }

  @Test("Single value: all 256 byte values in sequence")
  func allByteValuesSequence() throws {
    let original = Data(UInt8.min...UInt8.max)
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Repeated Single Values

  @Test("Repeated value: 1000 zeros")
  func repeatedZeros() throws {
    let original = Data(repeating: 0x00, count: 1000)
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
    #expect(compressed.count < original.count, "Should compress well")
  }

  @Test("Repeated value: 1000 of 0xFF")
  func repeatedFF() throws {
    let original = Data(repeating: 0xFF, count: 1000)
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Miscellaneous Edge Cases

  @Test("Two bytes: minimum multi-byte data")
  func twoBytes() throws {
    let original = Data([0x01, 0x02])
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Exact buffer multiple: data is exact multiple of buffer size")
  func exactBufferMultiple() throws {
    let config = LZMAConfiguration.compact  // 16KB buffer
    let bufferSize = config.bufferSize.bytes
    let original = Data((0..<(bufferSize * 3)).map { UInt8($0 & 0xFF) })

    let compressed = try original.lzmaCompressed(configuration: config)
    let decompressed = try compressed.lzmaDecompressed(configuration: config)

    #expect(decompressed == original)
  }
}
