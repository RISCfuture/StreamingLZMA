import Testing
import Foundation
@testable import StreamingLZMA

@Suite
struct `Corruption Handling Tests` {
  // MARK: - Truncation Tests

  @Test
  func `Truncation: remove last byte fails decompression`() throws {
    let original = Data("Hello, LZMA compression test data for truncation testing!".utf8)
    let compressed = try original.lzmaCompressed()

    let truncated = truncate(compressed, to: compressed.count - 1)

    #expect(throws: LZMAError.corruptedData) {
      try truncated.lzmaDecompressed()
    }
  }

  @Test
  func `Truncation: remove last 10 bytes fails decompression`() throws {
    let original = Data((0..<1000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    let truncated = truncate(compressed, to: compressed.count - 10)

    #expect(throws: LZMAError.corruptedData) {
      try truncated.lzmaDecompressed()
    }
  }

  @Test
  func `Truncation: truncate to half fails decompression`() throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    let truncated = truncate(compressed, to: compressed.count / 2)

    #expect(throws: LZMAError.corruptedData) {
      try truncated.lzmaDecompressed()
    }
  }

  // MARK: - Bit Flip Tests

  @Test
  func `Bit flip: single bit corruption causes error or wrong output`() throws {
    let original = Data("Test data for single bit flip corruption testing.".utf8)
    let compressed = try original.lzmaCompressed()

    // Flip a bit in the middle of the compressed data
    let byteIndex = compressed.count / 2
    let corrupted = flipBit(in: compressed, byteIndex: byteIndex, bitIndex: 3)

    // LZMA doesn't have built-in checksums, so corruption may either:
    // 1. Cause a decompression error, OR
    // 2. Produce silently corrupted output
    do {
      let decompressed = try corrupted.lzmaDecompressed()
      // If no error, the output should be different from original
      #expect(decompressed != original, "Corrupted data should not decompress to original")
    } catch {
      // Error is expected for corruption detection
    }
  }

  @Test
  func `Bit flip: corruption at start of data`() throws {
    let original = Data((0..<500).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Flip a bit in the first data byte
    let corrupted = flipBit(in: compressed, byteIndex: 0, bitIndex: 0)

    #expect(throws: LZMAError.corruptedData) {
      try corrupted.lzmaDecompressed()
    }
  }

  @Test
  func `Bit flip: corruption at end of data`() throws {
    let original = Data((0..<500).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Flip a bit in the last byte
    let corrupted = flipBit(in: compressed, byteIndex: compressed.count - 1, bitIndex: 7)

    #expect(throws: LZMAError.corruptedData) {
      try corrupted.lzmaDecompressed()
    }
  }

  @Test
  func `Byte replacement: corruption in middle`() throws {
    let original = Data((0..<1000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Replace a byte in the middle with a different value
    let byteIndex = compressed.count / 2
    let originalByte = compressed[byteIndex]
    let newByte = originalByte ^ 0xFF  // Invert all bits
    let corrupted = replaceByte(in: compressed, byteIndex: byteIndex, newValue: newByte)

    #expect(throws: LZMAError.corruptedData) {
      try corrupted.lzmaDecompressed()
    }
  }

  // MARK: - Random Garbage Tests

  @Test
  func `Random garbage data fails decompression`() {
    let garbage = randomData(count: 100)

    #expect(throws: LZMAError.corruptedData) {
      try garbage.lzmaDecompressed()
    }
  }

  @Test
  func `Completely random large data fails decompression`() {
    let garbage = randomData(count: 10000)

    #expect(throws: LZMAError.corruptedData) {
      try garbage.lzmaDecompressed()
    }
  }

  // MARK: - File Format Corruption Tests

  @Test
  func `File format: Apple ignores properties byte (behavioral test)`() throws {
    let original = Data("Test data for file format properties.".utf8)
    let compressed = try original.lzmaFileCompressed()

    // Apple's Compression framework ignores the properties byte in the header
    // and uses its own fixed parameters. This test documents this behavior.
    let corrupted = replaceByte(in: compressed, byteIndex: 0, newValue: 0xFF)

    // Decompression succeeds because Apple ignores the header properties
    let decompressed = try corrupted.lzmaFileDecompressed()
    #expect(decompressed == original, "Apple ignores properties byte, decompression should succeed")
  }

  @Test
  func `File format: truncated header`() {
    // Header should be 13 bytes - provide only 5
    let truncatedHeader = Data([0x5D, 0x00, 0x00, 0x80, 0x00])

    #expect(throws: LZMAError.corruptedData) {
      try truncatedHeader.lzmaFileDecompressed()
    }
  }

  @Test
  func `File format: valid header but corrupted stream`() throws {
    let original = Data("Test data with valid header but corrupted stream.".utf8)
    let compressed = try original.lzmaFileCompressed()

    // Corrupt a byte after the 13-byte header
    let corrupted = replaceByte(in: compressed, byteIndex: 14, newValue: 0x00)

    #expect(throws: LZMAError.corruptedData) {
      try corrupted.lzmaFileDecompressed()
    }
  }

  // MARK: - Streaming Corruption Detection Tests

  @Test
  func `Streaming: corruption detected during chunked decompression`() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Corrupt a byte in the middle
    let corrupted = replaceByte(in: compressed, byteIndex: compressed.count / 2, newValue: 0xFF)

    // Attempt chunked decompression - should throw during processing
    await #expect(throws: LZMAError.self) {
      try await decompressInChunks(corrupted, chunkSize: 100)
    }
  }

  @Test
  func `Streaming: truncation detected during chunked decompression`() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Truncate the compressed data
    let truncated = truncate(compressed, to: compressed.count / 2)

    // Attempt chunked decompression - should throw during finalization
    await #expect(throws: LZMAError.self) {
      try await decompressInChunks(truncated, chunkSize: 100)
    }
  }
}
