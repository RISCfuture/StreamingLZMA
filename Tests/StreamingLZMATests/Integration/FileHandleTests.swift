import Testing
import Foundation
@testable import StreamingLZMA

@Suite("FileHandle Extension Tests")
struct FileHandleTests {
  @Test("FileHandle compression round-trip")
  func fileHandleRoundTrip() throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })

    let tempDir = FileManager.default.temporaryDirectory
    let sourceURL = tempDir.appendingPathComponent("source_\(UUID().uuidString).bin")
    let compressedURL = tempDir.appendingPathComponent("compressed_\(UUID().uuidString).lzma")
    let decompressedURL = tempDir.appendingPathComponent("decompressed_\(UUID().uuidString).bin")

    defer {
      try? FileManager.default.removeItem(at: sourceURL)
      try? FileManager.default.removeItem(at: compressedURL)
      try? FileManager.default.removeItem(at: decompressedURL)
    }

    // Write source file
    try original.write(to: sourceURL)

    // Compress
    FileManager.default.createFile(atPath: compressedURL.path, contents: nil)
    let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
    let compressedHandle = try FileHandle(forWritingTo: compressedURL)
    defer {
      try? sourceHandle.close()
      try? compressedHandle.close()
    }

    try sourceHandle.lzmaCompress(to: compressedHandle)

    // Decompress
    FileManager.default.createFile(atPath: decompressedURL.path, contents: nil)
    let compressedReadHandle = try FileHandle(forReadingFrom: compressedURL)
    let decompressedHandle = try FileHandle(forWritingTo: decompressedURL)
    defer {
      try? compressedReadHandle.close()
      try? decompressedHandle.close()
    }

    try compressedReadHandle.lzmaDecompress(to: decompressedHandle)

    // Verify
    let decompressed = try Data(contentsOf: decompressedURL)
    #expect(decompressed == original)
  }

  @Test("FileHandle file format round-trip")
  func fileHandleFileFormatRoundTrip() throws {
    let original = Data("Hello, FileHandle LZMA file format!".utf8)

    let tempDir = FileManager.default.temporaryDirectory
    let sourceURL = tempDir.appendingPathComponent("source_\(UUID().uuidString).txt")
    let compressedURL = tempDir.appendingPathComponent("compressed_\(UUID().uuidString).lzma")
    let decompressedURL = tempDir.appendingPathComponent("decompressed_\(UUID().uuidString).txt")

    defer {
      try? FileManager.default.removeItem(at: sourceURL)
      try? FileManager.default.removeItem(at: compressedURL)
      try? FileManager.default.removeItem(at: decompressedURL)
    }

    // Write source file
    try original.write(to: sourceURL)

    // Compress with file format
    FileManager.default.createFile(atPath: compressedURL.path, contents: nil)
    let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
    let compressedHandle = try FileHandle(forWritingTo: compressedURL)
    defer {
      try? sourceHandle.close()
      try? compressedHandle.close()
    }

    try sourceHandle.lzmaFileCompress(to: compressedHandle)

    // Decompress with file format
    FileManager.default.createFile(atPath: decompressedURL.path, contents: nil)
    let compressedReadHandle = try FileHandle(forReadingFrom: compressedURL)
    let decompressedHandle = try FileHandle(forWritingTo: decompressedURL)
    defer {
      try? compressedReadHandle.close()
      try? decompressedHandle.close()
    }

    try compressedReadHandle.lzmaFileDecompress(to: decompressedHandle)

    // Verify
    let decompressed = try Data(contentsOf: decompressedURL)
    #expect(decompressed == original)
  }

  @Test("FileHandle progress callback is called")
  func fileHandleProgressCallback() throws {
    let original = Data((0..<100000).map { UInt8($0 & 0xFF) })

    let tempDir = FileManager.default.temporaryDirectory
    let sourceURL = tempDir.appendingPathComponent("source_\(UUID().uuidString).bin")
    let compressedURL = tempDir.appendingPathComponent("compressed_\(UUID().uuidString).lzma")

    defer {
      try? FileManager.default.removeItem(at: sourceURL)
      try? FileManager.default.removeItem(at: compressedURL)
    }

    try original.write(to: sourceURL)
    FileManager.default.createFile(atPath: compressedURL.path, contents: nil)

    let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
    let compressedHandle = try FileHandle(forWritingTo: compressedURL)
    defer {
      try? sourceHandle.close()
      try? compressedHandle.close()
    }

    var progressCalls: [Int64] = []
    try sourceHandle.lzmaCompress(to: compressedHandle) { bytesRead in
      progressCalls.append(bytesRead)
    }

    #expect(!progressCalls.isEmpty)
    #expect(progressCalls.last == Int64(original.count))
  }
}
