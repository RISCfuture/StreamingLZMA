import Foundation
import Testing
@testable import StreamingLZMA

// swiftlint:disable legacy_objc_type
// This file tests interoperability with NSData compression methods,
// which requires using NSData type conversions.

@Suite("XZ Interoperability Tests")
struct XZInteropTests {
  // MARK: - NSData Interoperability

  @Test("Decompress NSData.compressed output")
  func decompressNSDataOutput() throws {
    let original = Data("Test data for NSData interop".utf8)
    let compressed = try (original as NSData).compressed(using: .lzma) as Data
    let decompressed = try compressed.xzDecompressed()
    #expect(decompressed == original)
  }

  @Test("NSData can decompress our compressed output")
  func nsDataCanDecompressOurs() throws {
    let original = Data("Test data that NSData should be able to decompress".utf8)
    let compressed = try original.xzCompressed()
    let decompressed = try (compressed as NSData).decompressed(using: .lzma) as Data
    #expect(decompressed == original)
  }

  @Test("Round-trip with NSData")
  func roundTripWithNSData() throws {
    let original = Data("Round trip test between our library and NSData".utf8)

    // Compress with our library, decompress with NSData
    let ourCompressed = try original.xzCompressed()
    let nsDecompressed = try (ourCompressed as NSData).decompressed(using: .lzma) as Data
    #expect(nsDecompressed == original)

    // Compress with NSData, decompress with our library
    let nsCompressed = try (original as NSData).compressed(using: .lzma) as Data
    let ourDecompressed = try nsCompressed.xzDecompressed()
    #expect(ourDecompressed == original)
  }

  @Test("Large data NSData interop")
  func largeDataNSDataInterop() throws {
    let original = Data((0..<100_000).map { UInt8($0 & 0xFF) })

    // Our compression, NSData decompression
    let ourCompressed = try original.xzCompressed()
    let nsDecompressed = try (ourCompressed as NSData).decompressed(using: .lzma) as Data
    #expect(nsDecompressed == original)

    // NSData compression, our decompression
    let nsCompressed = try (original as NSData).compressed(using: .lzma) as Data
    let ourDecompressed = try nsCompressed.xzDecompressed()
    #expect(ourDecompressed == original)
  }

  @Test("Binary data NSData interop")
  func binaryDataNSDataInterop() throws {
    // Test with all byte values
    var original = Data()
    for i in 0..<256 {
      original.append(UInt8(i))
    }
    original.append(contentsOf: original)  // Double it

    let ourCompressed = try original.xzCompressed()
    let nsDecompressed = try (ourCompressed as NSData).decompressed(using: .lzma) as Data
    #expect(nsDecompressed == original)
  }

  // MARK: - CLI Interoperability

  @Test("Our compression is readable by xz CLI")
  func cliCanDecompress() throws {
    // Skip if xz is not available
    let checkResult = try? runCommand("which", "xz")
    guard checkResult != nil else {
      return  // xz not installed, skip test
    }

    let tempDir = FileManager.default.temporaryDirectory
    let compressedURL = tempDir.appendingPathComponent("cli_test_\(UUID().uuidString).xz")
    let decompressedURL = tempDir.appendingPathComponent("cli_output_\(UUID().uuidString).txt")

    defer {
      try? FileManager.default.removeItem(at: compressedURL)
      try? FileManager.default.removeItem(at: decompressedURL)
    }

    let original = Data("CLI interop test - our library compressed, xz CLI decompresses".utf8)
    let compressed = try original.xzCompressed()
    try compressed.write(to: compressedURL)

    // Use xz to decompress
    _ = try runCommand("xz", "-dk", compressedURL.path)

    // xz removes the .xz extension when decompressing
    let outputPath = compressedURL.path.replacingOccurrences(of: ".xz", with: "")
    let decompressed = try Data(contentsOf: URL(fileURLWithPath: outputPath))
    defer {
      try? FileManager.default.removeItem(atPath: outputPath)
    }

    #expect(decompressed == original)
  }

  @Test("xz CLI output is readable by our library")
  func canDecompressCLIOutput() throws {
    // Skip if xz is not available
    let checkResult = try? runCommand("which", "xz")
    guard checkResult != nil else {
      return  // xz not installed, skip test
    }

    let tempDir = FileManager.default.temporaryDirectory
    let sourceURL = tempDir.appendingPathComponent("cli_source_\(UUID().uuidString).txt")
    let compressedURL = URL(fileURLWithPath: sourceURL.path + ".xz")

    defer {
      try? FileManager.default.removeItem(at: sourceURL)
      try? FileManager.default.removeItem(at: compressedURL)
    }

    let original = Data("CLI interop test - xz CLI compresses, our library decompresses".utf8)
    try original.write(to: sourceURL)

    // Use xz to compress (keeps original by default with -k)
    _ = try runCommand("xz", "-k", sourceURL.path)

    let compressed = try Data(contentsOf: compressedURL)
    let decompressed = try compressed.xzDecompressed()

    #expect(decompressed == original)
  }

  // MARK: - Different XZ Options

  @Test("Different presets produce compatible output")
  func differentPresetsCompatible() throws {
    let original = Data("Test data for preset compatibility".utf8)

    for preset: UInt32 in [0, 3, 6, 9] {
      let config = XZConfiguration(preset: preset)
      let compressed = try original.xzCompressed(configuration: config)

      // Our library can decompress
      let ourDecompressed = try compressed.xzDecompressed()
      #expect(ourDecompressed == original)

      // NSData can decompress
      let nsDecompressed = try (compressed as NSData).decompressed(using: .lzma) as Data
      #expect(nsDecompressed == original)
    }
  }

  @Test("Different check types produce compatible output")
  func differentCheckTypesCompatible() throws {
    let original = Data("Test data for check type compatibility".utf8)

    for checkType: XZConfiguration.Check in [.none, .crc32, .crc64, .sha256] {
      let config = XZConfiguration(check: checkType)
      let compressed = try original.xzCompressed(configuration: config)

      // Our library can decompress
      let ourDecompressed = try compressed.xzDecompressed()
      #expect(ourDecompressed == original)

      // NSData can decompress
      let nsDecompressed = try (compressed as NSData).decompressed(using: .lzma) as Data
      #expect(nsDecompressed == original)
    }
  }

  // MARK: - XZ Format Validation

  @Test("XZ magic bytes are correct")
  func xzMagicBytes() throws {
    let original = Data("Test".utf8)
    let compressed = try original.xzCompressed()

    // XZ magic bytes: FD 37 7A 58 5A 00
    #expect(compressed.count >= 6)
    #expect(compressed[0] == 0xFD)
    #expect(compressed[1] == 0x37)
    #expect(compressed[2] == 0x7A)
    #expect(compressed[3] == 0x58)
    #expect(compressed[4] == 0x5A)
    #expect(compressed[5] == 0x00)
  }

  // MARK: - Streaming Interop

  @Test("Streaming compression compatible with NSData")
  func streamingCompressionNSDataCompatible() async throws {
    let original = Data("Streaming compression test for NSData compatibility".utf8)

    let compressor = try XZCompressor()
    var compressed = try await compressor.compress(original)
    compressed.append(try await compressor.finalize())

    // NSData can decompress streaming output
    let nsDecompressed = try (compressed as NSData).decompressed(using: .lzma) as Data
    #expect(nsDecompressed == original)
  }

  @Test("Streaming decompression handles NSData compressed input")
  func streamingDecompressionNSDataInput() async throws {
    let original = Data("Streaming decompression test with NSData input".utf8)
    let compressed = try (original as NSData).compressed(using: .lzma) as Data

    let decompressor = try XZDecompressor()
    var decompressed = try await decompressor.decompress(compressed)
    decompressed.append(try await decompressor.finalize())

    #expect(decompressed == original)
  }

  // MARK: - Helper

  private func runCommand(_ command: String, _ arguments: String...) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [command] + arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }
}

// swiftlint:enable legacy_objc_type
