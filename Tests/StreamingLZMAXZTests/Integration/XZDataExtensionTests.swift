import Foundation
import Testing
@testable import StreamingLZMAXZ

@Suite("XZ Data Extension Tests")
struct XZDataExtensionTests {
  // MARK: - Round-Trip Tests

  @Test("Round-trip small data")
  func roundTripSmallData() throws {
    let original = Data("A".utf8)  // Single byte
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Round-trip typical string data")
  func roundTripStringData() throws {
    let original = Data("Hello, XZ! This is a test of compression.".utf8)
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Round-trip 100 bytes")
  func roundTrip100Bytes() throws {
    let original = Data(repeating: 0xAB, count: 100)
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Round-trip 1KB")
  func roundTrip1KB() throws {
    let original = Data((0..<1024).map { UInt8($0 & 0xFF) })
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Round-trip 64KB")
  func roundTrip64KB() throws {
    let original = Data((0..<65536).map { UInt8($0 & 0xFF) })
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Round-trip 1MB")
  func roundTrip1MB() throws {
    let original = Data((0..<1_048_576).map { UInt8($0 & 0xFF) })
    let compressed = try original.xzCompressed()
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Buffer Size Configuration Tests

  @Test("Round-trip with small buffer")
  func roundTripSmallBuffer() throws {
    let original = Data("Test data for small buffer configuration.".utf8)
    let config = XZConfiguration.compact
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  @Test("Round-trip with large buffer")
  func roundTripLargeBuffer() throws {
    let original = Data("Test data for large buffer configuration.".utf8)
    let config = XZConfiguration.highThroughput
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  @Test("Round-trip with custom buffer size")
  func roundTripCustomBuffer() throws {
    let original = Data("Test data for custom buffer configuration.".utf8)
    let config = XZConfiguration(bufferSize: .custom(32 * 1024))
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed(configuration: config)
    #expect(decompressed == original)
  }

  // MARK: - Preset Tests

  @Test("Round-trip with fast preset")
  func roundTripFastPreset() throws {
    let original = Data("Test data with fast compression preset.".utf8)
    let config = XZConfiguration.fast
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Round-trip with best preset")
  func roundTripBestPreset() throws {
    let original = Data("Test data with best compression preset.".utf8)
    let config = XZConfiguration.best
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Fast preset produces larger output than best preset")
  func fastVsBestPreset() throws {
    let original = Data(repeating: 0xAB, count: 10000)
    let fastCompressed = try original.xzCompressed(configuration: .fast)
    let bestCompressed = try original.xzCompressed(configuration: .best)
    // Best should produce smaller or equal output
    #expect(bestCompressed.count <= fastCompressed.count)
  }

  // MARK: - Check Type Tests

  @Test("Round-trip with CRC32 check")
  func roundTripCRC32Check() throws {
    let original = Data("Test data with CRC32 integrity check.".utf8)
    let config = XZConfiguration(check: .crc32)
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Round-trip with CRC64 check")
  func roundTripCRC64Check() throws {
    let original = Data("Test data with CRC64 integrity check.".utf8)
    let config = XZConfiguration(check: .crc64)
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Round-trip with SHA256 check")
  func roundTripSHA256Check() throws {
    let original = Data("Test data with SHA256 integrity check.".utf8)
    let config = XZConfiguration(check: .sha256)
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("Round-trip with no check")
  func roundTripNoCheck() throws {
    let original = Data("Test data with no integrity check.".utf8)
    let config = XZConfiguration(check: .none)
    let compressed = try original.xzCompressed(configuration: config)
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Error Handling Tests

  @Test("Empty input throws emptyInput error")
  func emptyInputThrows() {
    let empty = Data()
    #expect(throws: XZError.emptyInput) {
      try empty.xzCompressed()
    }
  }

  @Test("Corrupted data throws corruptedData error")
  func corruptedDataThrows() {
    let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
    #expect(throws: XZError.corruptedData) {
      try garbage.xzDecompressed()
    }
  }

  // MARK: - Compression Effectiveness Tests

  @Test("Highly compressible data compresses well")
  func highlyCompressibleData() throws {
    let original = Data(repeating: 0x00, count: 10000)
    let compressed = try original.xzCompressed()
    #expect(compressed.count < original.count / 10)  // Should compress to <10%
  }

  @Test("Repeated pattern compresses")
  func repeatedPatternCompresses() throws {
    let pattern = Data("ABCDEFGH".utf8)
    var original = Data()
    for _ in 0..<1000 {
      original.append(pattern)
    }
    let compressed = try original.xzCompressed()
    #expect(compressed.count < original.count)
  }
}
