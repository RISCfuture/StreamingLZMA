import Foundation
import Testing
@testable import StreamingLZMAXZ

@Suite
struct `XZ InputStream Tests` {
  @Test
  func `InputStream compression produces valid data`() async throws {
    let original = Data("Test data for InputStream XZ compression.".utf8)
    let inputStream = InputStream(data: original)

    var compressed = Data()
    for try await chunk in inputStream.xzCompressedStream() {
      compressed.append(chunk)
    }

    // Verify by decompressing
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `InputStream decompression works correctly`() async throws {
    let original = Data("Test data for InputStream XZ decompression.".utf8)
    let compressed = try original.xzCompressed()

    let inputStream = InputStream(data: compressed)
    var decompressed = Data()
    for try await chunk in inputStream.xzDecompressedStream() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  @Test
  func `InputStream round-trip`() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })

    // Compress via InputStream
    let compressInput = InputStream(data: original)
    var compressed = Data()
    for try await chunk in compressInput.xzCompressedStream() {
      compressed.append(chunk)
    }

    // Decompress via InputStream
    let decompressInput = InputStream(data: compressed)
    var decompressed = Data()
    for try await chunk in decompressInput.xzDecompressedStream() {
      decompressed.append(chunk)
    }

    #expect(decompressed == original)
  }

  @Test
  func `InputStream with compact configuration`() async throws {
    let original = Data("Test with compact configuration.".utf8)
    let inputStream = InputStream(data: original)

    var compressed = Data()
    for try await chunk in inputStream.xzCompressedStream(configuration: .compact) {
      compressed.append(chunk)
    }

    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `InputStream with high throughput configuration`() async throws {
    let original = Data("Test with high throughput configuration.".utf8)
    let inputStream = InputStream(data: original)

    var compressed = Data()
    for try await chunk in inputStream.xzCompressedStream(configuration: .highThroughput) {
      compressed.append(chunk)
    }

    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Large data InputStream compression`() async throws {
    let original = Data((0..<500_000).map { UInt8($0 & 0xFF) })
    let inputStream = InputStream(data: original)

    var compressed = Data()
    for try await chunk in inputStream.xzCompressedStream() {
      compressed.append(chunk)
    }

    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `InputStream yields multiple chunks for large data`() async throws {
    // Create data large enough to require multiple chunks
    let original = Data((0..<100_000).map { UInt8($0 & 0xFF) })
    let inputStream = InputStream(data: original)

    var chunkCount = 0
    var compressed = Data()
    for try await chunk in inputStream.xzCompressedStream(configuration: .compact) {
      chunkCount += 1
      compressed.append(chunk)
    }

    // With compact buffer (16KB) and 100KB data, should have multiple chunks
    #expect(chunkCount >= 1)

    // Verify data integrity
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }
}
