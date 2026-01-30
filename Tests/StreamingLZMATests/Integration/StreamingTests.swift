import Testing
@testable import StreamingLZMA

@Suite("Streaming Tests")
struct StreamingTests {
  @Test("Streaming compressor produces same result as one-shot")
  func streamingMatchesOneShot() async throws {
    let original = Data("Hello, streaming LZMA compression test!".utf8)

    // One-shot
    let oneShotCompressed = try original.lzmaCompressed()

    // Streaming
    let compressor = try LZMACompressor()
    var streamingCompressed = try await compressor.compress(original)
    streamingCompressed.append(try await compressor.finalize())

    #expect(streamingCompressed == oneShotCompressed)
  }

  @Test("Streaming decompressor produces same result as one-shot")
  func streamingDecompressMatchesOneShot() async throws {
    let original = Data("Hello, streaming LZMA decompression test!".utf8)
    let compressed = try original.lzmaCompressed()

    // One-shot
    let oneShotDecompressed = try compressed.lzmaDecompressed()

    // Streaming
    let decompressor = try LZMADecompressor()
    var streamingDecompressed = try await decompressor.decompress(compressed)
    streamingDecompressed.append(try await decompressor.finalize())

    #expect(streamingDecompressed == oneShotDecompressed)
    #expect(streamingDecompressed == original)
  }

  @Test("Chunked streaming compression")
  func chunkedStreamingCompression() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })

    // Compress in chunks
    let compressor = try LZMACompressor()
    var compressed = Data()

    let chunkSize = 1000
    var offset = 0
    while offset < original.count {
      let end = min(offset + chunkSize, original.count)
      let chunk = original[offset..<end]
      compressed.append(try await compressor.compress(Data(chunk)))
      offset = end
    }
    compressed.append(try await compressor.finalize())

    // Decompress
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("Chunked streaming decompression")
  func chunkedStreamingDecompression() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Decompress in chunks
    let decompressor = try LZMADecompressor()
    var decompressed = Data()

    let chunkSize = 100
    var offset = 0
    while offset < compressed.count {
      let end = min(offset + chunkSize, compressed.count)
      let chunk = compressed[offset..<end]
      decompressed.append(try await decompressor.decompress(Data(chunk)))
      offset = end
    }
    decompressed.append(try await decompressor.finalize())

    #expect(decompressed == original)
  }

  @Test("Multiple streams can run concurrently")
  func concurrentStreams() async throws {
    let data1 = Data("First data stream".utf8)
    let data2 = Data("Second data stream".utf8)
    let data3 = Data("Third data stream".utf8)

    // Create separate compressors for parallel processing
    async let result1 = compressAndDecompress(data1)
    async let result2 = compressAndDecompress(data2)
    async let result3 = compressAndDecompress(data3)

    let (r1, r2, r3) = try await (result1, result2, result3)

    #expect(r1 == data1)
    #expect(r2 == data2)
    #expect(r3 == data3)
  }

  private func compressAndDecompress(_ data: Data) async throws -> Data {
    let compressor = try LZMACompressor()
    var compressed = try await compressor.compress(data)
    compressed.append(try await compressor.finalize())

    let decompressor = try LZMADecompressor()
    var decompressed = try await decompressor.decompress(compressed)
    decompressed.append(try await decompressor.finalize())

    return decompressed
  }
}
