import Foundation
import Testing
@testable import StreamingLZMA

@Suite("XZ FileHandle Tests")
struct XZFileHandleTests {
  @Test("Round-trip file compression")
  func roundTripFileCompression() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceURL = tempDir.appendingPathComponent("xz_source_\(UUID().uuidString).bin")
    let compressedURL = tempDir.appendingPathComponent("xz_compressed_\(UUID().uuidString).xz")
    let decompressedURL = tempDir.appendingPathComponent("xz_decompressed_\(UUID().uuidString).bin")

    defer {
      try? FileManager.default.removeItem(at: sourceURL)
      try? FileManager.default.removeItem(at: compressedURL)
      try? FileManager.default.removeItem(at: decompressedURL)
    }

    // Create test data
    let original = Data("Test file compression with XZ format.".utf8)
    try original.write(to: sourceURL)
    FileManager.default.createFile(atPath: compressedURL.path, contents: nil)
    FileManager.default.createFile(atPath: decompressedURL.path, contents: nil)

    // Compress
    let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
    let compressedHandle = try FileHandle(forWritingTo: compressedURL)
    defer {
      try? sourceHandle.close()
      try? compressedHandle.close()
    }

    try sourceHandle.xzCompress(to: compressedHandle)

    // Decompress
    let compressedReadHandle = try FileHandle(forReadingFrom: compressedURL)
    let decompressedHandle = try FileHandle(forWritingTo: decompressedURL)
    defer {
      try? compressedReadHandle.close()
      try? decompressedHandle.close()
    }

    try compressedReadHandle.xzDecompress(to: decompressedHandle)

    // Verify
    let decompressed = try Data(contentsOf: decompressedURL)
    #expect(decompressed == original)
  }

  @Test("Progress callback is called during compression")
  func progressCallbackCompression() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceURL = tempDir.appendingPathComponent("xz_progress_source_\(UUID().uuidString).bin")
    let compressedURL = tempDir.appendingPathComponent(
      "xz_progress_compressed_\(UUID().uuidString).xz"
    )

    defer {
      try? FileManager.default.removeItem(at: sourceURL)
      try? FileManager.default.removeItem(at: compressedURL)
    }

    // Create large test data
    let original = Data((0..<100_000).map { UInt8($0 & 0xFF) })
    try original.write(to: sourceURL)
    FileManager.default.createFile(atPath: compressedURL.path, contents: nil)

    let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
    let compressedHandle = try FileHandle(forWritingTo: compressedURL)
    defer {
      try? sourceHandle.close()
      try? compressedHandle.close()
    }

    var progressCalls: [Int64] = []
    try sourceHandle.xzCompress(to: compressedHandle) { bytesRead in
      progressCalls.append(bytesRead)
    }

    // Progress should have been called at least once
    #expect(!progressCalls.isEmpty)
    // Last progress call should reflect total bytes
    let lastCompressionProgress = try #require(progressCalls.last)
    #expect(lastCompressionProgress == Int64(original.count))
  }

  @Test("Progress callback is called during decompression")
  func progressCallbackDecompression() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let compressedURL = tempDir.appendingPathComponent(
      "xz_decompress_progress_\(UUID().uuidString).xz"
    )
    let decompressedURL = tempDir.appendingPathComponent(
      "xz_decompress_output_\(UUID().uuidString).bin"
    )

    defer {
      try? FileManager.default.removeItem(at: compressedURL)
      try? FileManager.default.removeItem(at: decompressedURL)
    }

    // Create compressed data
    let original = Data((0..<100_000).map { UInt8($0 & 0xFF) })
    let compressed = try original.xzCompressed()
    try compressed.write(to: compressedURL)
    FileManager.default.createFile(atPath: decompressedURL.path, contents: nil)

    let compressedHandle = try FileHandle(forReadingFrom: compressedURL)
    let decompressedHandle = try FileHandle(forWritingTo: decompressedURL)
    defer {
      try? compressedHandle.close()
      try? decompressedHandle.close()
    }

    var progressCalls: [Int64] = []
    try compressedHandle.xzDecompress(to: decompressedHandle) { bytesRead in
      progressCalls.append(bytesRead)
    }

    // Progress should have been called at least once
    #expect(!progressCalls.isEmpty)
    // Last progress call should reflect compressed size
    let lastDecompressionProgress = try #require(progressCalls.last)
    #expect(lastDecompressionProgress == Int64(compressed.count))

    // Verify decompression
    let decompressed = try Data(contentsOf: decompressedURL)
    #expect(decompressed == original)
  }

  @Test("Large file round-trip")
  func largeFileRoundTrip() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceURL = tempDir.appendingPathComponent("xz_large_source_\(UUID().uuidString).bin")
    let compressedURL = tempDir.appendingPathComponent(
      "xz_large_compressed_\(UUID().uuidString).xz"
    )
    let decompressedURL = tempDir.appendingPathComponent(
      "xz_large_decompressed_\(UUID().uuidString).bin"
    )

    defer {
      try? FileManager.default.removeItem(at: sourceURL)
      try? FileManager.default.removeItem(at: compressedURL)
      try? FileManager.default.removeItem(at: decompressedURL)
    }

    // Create 1MB test data
    let original = Data((0..<1_048_576).map { UInt8($0 & 0xFF) })
    try original.write(to: sourceURL)
    FileManager.default.createFile(atPath: compressedURL.path, contents: nil)
    FileManager.default.createFile(atPath: decompressedURL.path, contents: nil)

    // Compress
    let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
    let compressedHandle = try FileHandle(forWritingTo: compressedURL)
    try sourceHandle.xzCompress(to: compressedHandle)
    try sourceHandle.close()
    try compressedHandle.close()

    // Decompress
    let compressedReadHandle = try FileHandle(forReadingFrom: compressedURL)
    let decompressedHandle = try FileHandle(forWritingTo: decompressedURL)
    try compressedReadHandle.xzDecompress(to: decompressedHandle)
    try compressedReadHandle.close()
    try decompressedHandle.close()

    // Verify
    let decompressed = try Data(contentsOf: decompressedURL)
    #expect(decompressed == original)
  }

  @Test("Different buffer sizes produce same result")
  func differentBufferSizes() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceURL = tempDir.appendingPathComponent("xz_buffer_source_\(UUID().uuidString).bin")
    let compressedSmallURL = tempDir.appendingPathComponent(
      "xz_compressed_small_\(UUID().uuidString).xz"
    )
    let compressedLargeURL = tempDir.appendingPathComponent(
      "xz_compressed_large_\(UUID().uuidString).xz"
    )

    defer {
      try? FileManager.default.removeItem(at: sourceURL)
      try? FileManager.default.removeItem(at: compressedSmallURL)
      try? FileManager.default.removeItem(at: compressedLargeURL)
    }

    let original = Data("Buffer size test data that should compress the same.".utf8)
    try original.write(to: sourceURL)
    FileManager.default.createFile(atPath: compressedSmallURL.path, contents: nil)
    FileManager.default.createFile(atPath: compressedLargeURL.path, contents: nil)

    // Compress with small buffer
    let sourceSmall = try FileHandle(forReadingFrom: sourceURL)
    let compressedSmall = try FileHandle(forWritingTo: compressedSmallURL)
    try sourceSmall.xzCompress(to: compressedSmall, configuration: .compact)
    try sourceSmall.close()
    try compressedSmall.close()

    // Compress with large buffer
    let sourceLarge = try FileHandle(forReadingFrom: sourceURL)
    let compressedLarge = try FileHandle(forWritingTo: compressedLargeURL)
    try sourceLarge.xzCompress(to: compressedLarge, configuration: .highThroughput)
    try sourceLarge.close()
    try compressedLarge.close()

    // Both should decompress to the same data
    let dataSmall = try Data(contentsOf: compressedSmallURL)
    let dataLarge = try Data(contentsOf: compressedLargeURL)

    #expect(try dataSmall.xzDecompressed() == original)
    #expect(try dataLarge.xzDecompressed() == original)
  }
}
