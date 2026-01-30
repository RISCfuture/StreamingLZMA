import Testing
import Foundation
@testable import StreamingLZMA

@Suite("InputStream Extension Tests")
struct InputStreamTests {
  @Test("InputStream compression stream produces valid output")
  func inputStreamCompression() async throws {
    let original = Data("Hello, InputStream LZMA compression!".utf8)
    let inputStream = InputStream(data: original)

    var compressed = Data()
    for try await chunk in inputStream.lzmaCompressedStream() {
      compressed.append(chunk)
    }

    // Verify by decompressing
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("InputStream decompression stream produces valid output")
  func inputStreamDecompression() async throws {
    let original = Data("Hello, InputStream LZMA decompression!".utf8)
    let compressed = try original.lzmaCompressed()

    let inputStream = InputStream(data: compressed)

    var decompressed = Data()
    for try await chunk in inputStream.lzmaDecompressedStream() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  @Test("InputStream with larger data")
  func inputStreamLargerData() async throws {
    let original = Data((0..<50000).map { UInt8($0 & 0xFF) })
    let inputStream = InputStream(data: original)

    var compressed = Data()
    for try await chunk in inputStream.lzmaCompressedStream() {
      compressed.append(chunk)
    }

    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test("InputStream round-trip through streams")
  func inputStreamRoundTrip() async throws {
    let original = Data("Full round-trip test through input streams!".utf8)

    // Compress via stream
    let compressStream = InputStream(data: original)
    var compressed = Data()
    for try await chunk in compressStream.lzmaCompressedStream() {
      compressed.append(chunk)
    }

    // Decompress via stream
    let decompressStream = InputStream(data: compressed)
    var decompressed = Data()
    for try await chunk in decompressStream.lzmaDecompressedStream() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  @Test("InputStream with custom configuration")
  func inputStreamCustomConfig() async throws {
    let original = Data("Test with custom configuration".utf8)
    let config = LZMAConfiguration.compact

    let inputStream = InputStream(data: original)

    var compressed = Data()
    for try await chunk in inputStream.lzmaCompressedStream(configuration: config) {
      compressed.append(chunk)
    }

    let decompressed = try compressed.lzmaDecompressed(configuration: config)
    #expect(decompressed == original)
  }
}
