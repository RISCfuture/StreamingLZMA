import Testing
import Foundation
@testable import StreamingLZMA

@Suite("Corruption Handling Tests")
struct CorruptionHandlingTests {
  // MARK: - Truncation Tests

  @Test("Truncation: remove last byte fails decompression")
  func truncationRemoveLastByte() throws {
    let original = Data("Hello, LZMA compression test data for truncation testing!".utf8)
    let compressed = try original.lzmaCompressed()

    let truncated = truncate(compressed, to: compressed.count - 1)

    #expect(throws: LZMAError.corruptedData) {
      try truncated.lzmaDecompressed()
    }
  }

  @Test("Truncation: remove last 10 bytes fails decompression")
  func truncationRemoveLast10Bytes() throws {
    let original = Data((0..<1000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    let truncated = truncate(compressed, to: compressed.count - 10)

    #expect(throws: LZMAError.corruptedData) {
      try truncated.lzmaDecompressed()
    }
  }

  @Test("Truncation: truncate to half fails decompression")
  func truncationToHalf() throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    let truncated = truncate(compressed, to: compressed.count / 2)

    #expect(throws: LZMAError.corruptedData) {
      try truncated.lzmaDecompressed()
    }
  }

  // MARK: - Bit Flip Tests

  @Test("Bit flip: single bit corruption causes error or wrong output")
  func singleBitFlip() throws {
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
    } catch is LZMAError {
      // Error is expected for corruption detection
    }
  }

  @Test("Bit flip: corruption at start of data")
  func bitFlipAtStart() throws {
    let original = Data((0..<500).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Flip a bit in the first data byte
    let corrupted = flipBit(in: compressed, byteIndex: 0, bitIndex: 0)

    #expect(throws: LZMAError.corruptedData) {
      try corrupted.lzmaDecompressed()
    }
  }

  @Test("Bit flip: corruption at end of data")
  func bitFlipAtEnd() throws {
    let original = Data((0..<500).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Flip a bit in the last byte
    let corrupted = flipBit(in: compressed, byteIndex: compressed.count - 1, bitIndex: 7)

    #expect(throws: LZMAError.corruptedData) {
      try corrupted.lzmaDecompressed()
    }
  }

  @Test("Byte replacement: corruption in middle")
  func byteReplacementMiddle() throws {
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

  @Test("Random garbage data fails decompression")
  func randomGarbageFails() {
    let garbage = randomData(count: 100)

    #expect(throws: LZMAError.corruptedData) {
      try garbage.lzmaDecompressed()
    }
  }

  @Test("Completely random large data fails decompression")
  func randomLargeGarbageFails() {
    let garbage = randomData(count: 10000)

    #expect(throws: LZMAError.corruptedData) {
      try garbage.lzmaDecompressed()
    }
  }

  // MARK: - File Format Corruption Tests

  @Test("File format: Apple ignores properties byte (behavioral test)")
  func fileFormatPropertiesByteIgnored() throws {
    let original = Data("Test data for file format properties.".utf8)
    let compressed = try original.lzmaFileCompressed()

    // Apple's Compression framework ignores the properties byte in the header
    // and uses its own fixed parameters. This test documents this behavior.
    let corrupted = replaceByte(in: compressed, byteIndex: 0, newValue: 0xFF)

    // Decompression succeeds because Apple ignores the header properties
    let decompressed = try corrupted.lzmaFileDecompressed()
    #expect(decompressed == original, "Apple ignores properties byte, decompression should succeed")
  }

  @Test("File format: truncated header")
  func fileFormatTruncatedHeader() {
    // Header should be 13 bytes - provide only 5
    let truncatedHeader = Data([0x5D, 0x00, 0x00, 0x80, 0x00])

    #expect(throws: LZMAError.corruptedData) {
      try truncatedHeader.lzmaFileDecompressed()
    }
  }

  @Test("File format: valid header but corrupted stream")
  func fileFormatValidHeaderCorruptedStream() throws {
    let original = Data("Test data with valid header but corrupted stream.".utf8)
    let compressed = try original.lzmaFileCompressed()

    // Corrupt a byte after the 13-byte header
    let corrupted = replaceByte(in: compressed, byteIndex: 14, newValue: 0x00)

    #expect(throws: LZMAError.corruptedData) {
      try corrupted.lzmaFileDecompressed()
    }
  }

  // MARK: - Streaming Corruption Detection Tests

  @Test("Streaming: corruption detected during chunked decompression")
  func streamingCorruptionDetection() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()

    // Corrupt a byte in the middle
    let corrupted = replaceByte(in: compressed, byteIndex: compressed.count / 2, newValue: 0xFF)

    // Attempt chunked decompression - should throw during processing
    await #expect(throws: LZMAError.self) {
      try await decompressInChunks(corrupted, chunkSize: 100)
    }
  }

  @Test("Streaming: truncation detected during chunked decompression")
  func streamingTruncationDetection() async throws {
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
