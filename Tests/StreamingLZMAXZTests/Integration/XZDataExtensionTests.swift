import Foundation
import Testing
@testable import StreamingLZMAXZ

@Suite
struct `XZ Data Extension Tests` {
  // MARK: - Round-Trip Tests

  @Test
  func `Round-trip small data`() throws {
    let original = Data("A".utf8)  // Single byte
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip typical string data`() throws {
    let original = Data("Hello, XZ! This is a test of compression.".utf8)
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip 100 bytes`() throws {
    let original = Data(repeating: 0xAB, count: 100)
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip 1KB`() throws {
    let original = Data((0..<1024).map { UInt8($0 & 0xFF) })
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip 64KB`() throws {
    let original = Data((0..<65536).map { UInt8($0 & 0xFF) })
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip 1MB`() throws {
    let original = Data((0..<1_048_576).map { UInt8($0 & 0xFF) })
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Buffer Size Configuration Tests

  @Test
  func `Round-trip with small buffer`() throws {
    let original = Data("Test data for small buffer configuration.".utf8)
    let config = XZConfiguration.compact
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip with large buffer`() throws {
    let original = Data("Test data for large buffer configuration.".utf8)
    let config = XZConfiguration.highThroughput
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip with custom buffer size`() throws {
    let original = Data("Test data for custom buffer configuration.".utf8)
    let config = XZConfiguration(bufferSize: .custom(32 * 1024))
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  // MARK: - Preset Tests

  @Test
  func `Round-trip with fast preset`() throws {
    let original = Data("Test data with fast compression preset.".utf8)
    let config = XZConfiguration.fast
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip with best preset`() throws {
    let original = Data("Test data with best compression preset.".utf8)
    let config = XZConfiguration.best
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Fast preset produces larger output than best preset`() throws {
    let original = Data(repeating: 0xAB, count: 10000)
    let fastCompressed = try original.xzCompressed(configuration: .fast)
    let bestCompressed = try original.xzCompressed(configuration: .best)
    // Best should produce smaller or equal output
    #expect(bestCompressed.count <= fastCompressed.count)
  }

  // MARK: - Check Type Tests

  @Test
  func `Round-trip with CRC32 check`() throws {
    let original = Data("Test data with CRC32 integrity check.".utf8)
    let config = XZConfiguration(check: .crc32)
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip with CRC64 check`() throws {
    let original = Data("Test data with CRC64 integrity check.".utf8)
    let config = XZConfiguration(check: .crc64)
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip with SHA256 check`() throws {
    let original = Data("Test data with SHA256 integrity check.".utf8)
    let config = XZConfiguration(check: .sha256)
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Round-trip with no check`() throws {
    let original = Data("Test data with no integrity check.".utf8)
    let config = XZConfiguration(check: .none)
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Error Handling Tests

  @Test
  func `Empty input throws emptyInput error`() {
    let empty = Data()
    #expect(throws: XZError.emptyInput) {
      try empty.xzCompressed()
    }
  }

  @Test
  func `Corrupted data throws corruptedData error`() {
    let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
    #expect(throws: XZError.corruptedData) {
      try garbage.xzDecompressed()
    }
  }

  // MARK: - Compression Effectiveness Tests

  @Test
  func `Highly compressible data compresses well`() throws {
    let original = Data(repeating: 0x00, count: 10000)
    let compressed = try original.xzCompressed()
    #expect(compressed.count < original.count / 10)  // Should compress to <10%
  }

  @Test
  func `Repeated pattern compresses`() throws {
    let pattern = Data("ABCDEFGH".utf8)
    var original = Data()
    for _ in 0..<1000 {
      original.append(pattern)
    }
    let compressed = try original.xzCompressed()
    #expect(compressed.count < original.count)
  }
}
