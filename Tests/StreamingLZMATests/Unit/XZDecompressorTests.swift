import Testing
@testable import StreamingLZMA

@Suite("XZDecompressor Tests")
struct XZDecompressorTests {
  @Test("Decompressor processes valid data")
  func decompressorProcessesData() async throws {
    // First compress some data
    let original = Data("Hello, World!".utf8)
    let compressed = try original.xzCompressed()

    // Then decompress it
    let decompressor = try XZDecompressor()
    var decompressed = try await decompressor.decompress(compressed)
    decompressed.append(try await decompressor.finalize())

    #expect(decompressed == original)
  }

  @Test("Decompressor can be reset")
  func decompressorReset() async throws {
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

  @Test("Decompressor throws when processing after finalize")
  func decompressorThrowsAfterFinalize() async throws {
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

  @Test("Decompressor throws when finalizing twice")
  func decompressorThrowsOnDoubleFinalize() async throws {
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
