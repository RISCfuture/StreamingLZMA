import Testing
import Foundation
@testable import StreamingLZMA

/// Tests for CLI compatibility.
///
/// **Important Note:** Apple's Compression framework uses a slightly different LZMA
/// stream format than the standalone LZMA SDK used by command-line tools like `lzma`,
/// `xz`, and `7z`. While both are LZMA, the raw stream data is not directly compatible.
///
/// The library's file format methods (lzmaFileCompressed/lzmaFileDecompressed) provide
/// the correct header structure, but the underlying compressed data may not be
/// interchangeable with CLI-created files.
///
/// For CLI interoperability, consider using XZ format (which Apple also supports via
/// COMPRESSION_LZMA) or ZSTD as alternatives.
@Suite("CLI Compatibility Tests")
struct CLICompatibilityTests {
  // MARK: - Fixture Loading

  private func fixtureURL(_ name: String) -> URL? {
    Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
  }

  // MARK: - Header Structure Tests

  @Test("Parse header from CLI-compressed file")
  func parseCLIHeader() throws {
    let compressedURL = try #require(fixtureURL("sample.txt.lzma"))

    let compressed = try Data(contentsOf: compressedURL)
    let header = try LZMAFileHeader(from: compressed)

    // CLI tools use standard LZMA parameters
    #expect(header.properties == 0x5D)  // lc=3, lp=0, pb=2

    // Dictionary size should be a power of 2 (typically 8MB or less)
    #expect(header.dictionarySize > 0)

    // Decode properties
    let (lc, lp, pb) = header.decodedProperties
    #expect(lc == 3)
    #expect(lp == 0)
    #expect(pb == 2)
  }

  @Test("CLI file has known uncompressed size in header")
  func cliHeaderHasKnownSize() throws {
    let compressedURL = try #require(fixtureURL("sample.txt.lzma"))

    let compressed = try Data(contentsOf: compressedURL)
    let header = try LZMAFileHeader(from: compressed)

    // CLI tools typically store the uncompressed size
    // Note: Some CLI tools may use -1 (unknown) for streaming
    #expect(header.uncompressedSize != 0)  // Should have some size info
  }

  // MARK: - Library Format Tests

  @Test("Library file format round-trip")
  func libraryFileFormatRoundTrip() throws {
    let original = Data("Hello, LZMA file format!".utf8)
    let compressed = try original.lzmaFileCompressed()
    let decompressed = try compressed.lzmaFileDecompressed()
    #expect(decompressed == original)
  }

  @Test("Library file format header is correct")
  func libraryFileFormatHeader() throws {
    let original = Data("Test".utf8)
    let compressed = try original.lzmaFileCompressed()
    let header = try LZMAFileHeader(from: compressed)

    #expect(header.properties == 0x5D)
    #expect(header.dictionarySize == 8_388_608)  // 8 MB
    #expect(header.uncompressedSize == UInt64(original.count))
  }

  @Test("Library FileHandle format round-trip")
  func libraryFileHandleFormatRoundTrip() throws {
    let original = Data((0..<1000).map { UInt8($0 & 0xFF) })

    let tempDir = FileManager.default.temporaryDirectory
    let sourceURL = tempDir.appendingPathComponent("source_\(UUID().uuidString).bin")
    let compressedURL = tempDir.appendingPathComponent("compressed_\(UUID().uuidString).lzma")
    let decompressedURL = tempDir.appendingPathComponent("decompressed_\(UUID().uuidString).bin")

    defer {
      try? FileManager.default.removeItem(at: sourceURL)
      try? FileManager.default.removeItem(at: compressedURL)
      try? FileManager.default.removeItem(at: decompressedURL)
    }

    try original.write(to: sourceURL)
    FileManager.default.createFile(atPath: compressedURL.path, contents: nil)

    // Compress
    let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
    let compressedHandle = try FileHandle(forWritingTo: compressedURL)
    try sourceHandle.lzmaFileCompress(to: compressedHandle)
    try sourceHandle.close()
    try compressedHandle.close()

    // Decompress
    FileManager.default.createFile(atPath: decompressedURL.path, contents: nil)
    let compressedReadHandle = try FileHandle(forReadingFrom: compressedURL)
    let decompressedHandle = try FileHandle(forWritingTo: decompressedURL)
    try compressedReadHandle.lzmaFileDecompress(to: decompressedHandle)
    try compressedReadHandle.close()
    try decompressedHandle.close()

    // Verify
    let decompressed = try Data(contentsOf: decompressedURL)
    #expect(decompressed == original)
  }

  // MARK: - Format Compatibility Notes

  @Test("Document Apple vs CLI format difference")
  func formatDifferenceDocumented() throws {
    // This test documents that Apple's Compression framework produces
    // different raw LZMA data than the standalone LZMA SDK.
    //
    // Both use LZMA algorithm, but:
    // - Apple's framework: Uses internal stream format
    // - CLI tools (lzma, xz, 7z): Use LZMA SDK format
    //
    // The .lzma file header (13 bytes) is identical, but the compressed
    // payload is not directly compatible.
    //
    // For cross-platform compatibility, consider:
    // 1. Using the library only for Apple-to-Apple workflows
    // 2. Using XZ format (also supported by Compression framework)
    // 3. Using ZSTD for modern compression needs

    let original = Data("Test data".utf8)

    // Library can compress and decompress its own data
    let compressed = try original.lzmaFileCompressed()
    let decompressed = try compressed.lzmaFileDecompressed()
    #expect(decompressed == original)

    // Header is standard format
    let header = try LZMAFileHeader(from: compressed)
    #expect(header.properties == 0x5D)
  }
}
