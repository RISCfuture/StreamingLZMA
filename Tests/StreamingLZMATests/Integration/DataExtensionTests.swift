import Foundation
import Testing
@testable import StreamingLZMA

@Suite
struct `Data Extension Tests` {
  // MARK: - Round-Trip Tests

  @Test
  func `Round-trip empty-adjacent small data`() throws {
    let original = Data("A".utf8)  // Single byte
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip typical string data`() throws {
    let original = Data("Hello, LZMA! This is a test of compression.".utf8)
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip 100 bytes`() throws {
    let original = Data(repeating: 0xAB, count: 100)
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip 1KB`() throws {
    let original = Data((0..<1024).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip 64KB`() throws {
    let original = Data((0..<65536).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip 1MB`() throws {
    let original = Data((0..<1_048_576).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Buffer Size Configuration Tests

  @Test
  func `Round-trip with small buffer`() throws {
    let original = Data("Test data for small buffer configuration.".utf8)
    let config = LZMAConfiguration.compact
    let compressed = try original.lzmaCompressed(configuration: config)
    let decompressed = try compressed.lzmaDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip with large buffer`() throws {
    let original = Data("Test data for large buffer configuration.".utf8)
    let config = LZMAConfiguration.highThroughput
    let compressed = try original.lzmaCompressed(configuration: config)
    let decompressed = try compressed.lzmaDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip with custom buffer size`() throws {
    let original = Data("Test data for custom buffer configuration.".utf8)
    let config = LZMAConfiguration(bufferSize: .custom(32 * 1024))
    let compressed = try original.lzmaCompressed(configuration: config)
    let decompressed = try compressed.lzmaDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  // MARK: - Error Handling Tests

  @Test
  func `Empty input throws emptyInput error`() {
    let empty = Data()
    #expect(throws: LZMAError.emptyInput) {
      try empty.lzmaCompressed()
    }
  }

  @Test
  func `Corrupted data throws corruptedData error`() {
    let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
    #expect(throws: LZMAError.corruptedData) {
      try garbage.lzmaDecompressed()
    }
  }

  // MARK: - Compression Effectiveness Tests

  @Test
  func `Highly compressible data compresses well`() throws {
    let original = Data(repeating: 0x00, count: 10000)
    let compressed = try original.lzmaCompressed()
    #expect(compressed.count < original.count / 10)  // Should compress to <10%
  }

  @Test
  func `Repeated pattern compresses`() throws {
    let pattern = Data("ABCDEFGH".utf8)
    var original = Data()
    for _ in 0..<1000 {
      original.append(pattern)
    }
    let compressed = try original.lzmaCompressed()
    #expect(compressed.count < original.count)
  }

  // MARK: - File Format Tests

  @Test
  func `File format round-trip`() throws {
    let original = Data("Hello, LZMA file format!".utf8)
    let compressed = try original.lzmaFileCompressed()
    let decompressed = try compressed.lzmaFileDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `File format has correct header size`() throws {
    let original = Data("Test".utf8)
    let compressed = try original.lzmaFileCompressed()
    #expect(compressed.count >= 13)  // At least header size
  }

  @Test
  func `File format header can be parsed`() throws {
    let original = Data("Test".utf8)
    let compressed = try original.lzmaFileCompressed()
    let header = try LZMAFileHeader(from: compressed)
    #expect(header.properties == 0x5D)
    #expect(header.uncompressedSize == UInt64(original.count))
  }

  @Test
  func `File format decompression fails on too-short data`() {
    let short = Data([0x5D, 0x00, 0x00])
    #expect(throws: LZMAError.corruptedData) {
      try short.lzmaFileDecompressed()
    }
  }
}
