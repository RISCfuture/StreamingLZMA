import Foundation
import Testing
@testable import StreamingLZMAXZ

@Suite
struct `XZDecompressor Tests` {
  @Test
  func `Decompressor processes valid data`() async throws {
    // First compress some data
    let original = Data("Hello, World!".utf8)
    let compressed = try original.xzCompressed()

    // Then decompress it
    let decompressor = try XZDecompressor()
    var decompressed = try await decompressor.decompress(compressed)
    decompressed.append(try await decompressor.finalize())

    #expect(decompressed == original)
  }

  @Test
  func `Decompressor can be reset`() async throws {
    let original = Data("Hello".utf8)
    let compressed = try original.xzCompressed()

    let decompressor = try XZDecompressor()
    var decompressed = try await decompressor.decompress(compressed)
    decompressed.append(try await decompressor.finalize())

    #expect(decompressed == original)

    // Reset and use again
    try await decompressor.reset()

    decompressed = try await decompressor.decompress(compressed)
    decompressed.append(try await decompressor.finalize())

    #expect(decompressed == original)
  }

  @Test
  func `Decompressor throws when processing after finalize`() async throws {
    let original = Data("Hello".utf8)
    let compressed = try original.xzCompressed()

    let decompressor = try XZDecompressor()
    _ = try await decompressor.decompress(compressed)
    _ = try await decompressor.finalize()

    // Should throw on subsequent operations
    await #expect(throws: XZError.streamAlreadyFinalized) {
      try await decompressor.decompress(compressed)
    }
  }

  @Test
  func `Decompressor throws when finalizing twice`() async throws {
    let original = Data("Hello".utf8)
    let compressed = try original.xzCompressed()

    let decompressor = try XZDecompressor()
    _ = try await decompressor.decompress(compressed)
    _ = try await decompressor.finalize()

    await #expect(throws: XZError.streamAlreadyFinalized) {
      try await decompressor.finalize()
    }
  }
}
