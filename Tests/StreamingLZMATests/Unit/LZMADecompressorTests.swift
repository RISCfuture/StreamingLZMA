import Testing
@testable import StreamingLZMA

@Suite("LZMADecompressor Tests")
struct LZMADecompressorTests {
  @Test("Decompressor can be reset")
  func decompressorReset() async throws {
    let decompressor = try LZMADecompressor()

    // First use (with valid compressed data)
    let input = Data("Hello".utf8)
    let compressed = try input.lzmaCompressed()

    _ = try await decompressor.decompress(compressed)
    _ = try await decompressor.finalize()

    // Reset and use again
    try await decompressor.reset()

    _ = try await decompressor.decompress(compressed)
    _ = try await decompressor.finalize()
  }

  @Test("Decompressor throws when processing after finalize")
  func decompressorThrowsAfterFinalize() async throws {
    let decompressor = try LZMADecompressor()
    let input = Data("Hello".utf8)
    let compressed = try input.lzmaCompressed()

    _ = try await decompressor.decompress(compressed)
    _ = try await decompressor.finalize()

    await #expect(throws: LZMAError.streamAlreadyFinalized) {
      try await decompressor.decompress(compressed)
    }
  }

  @Test("Decompressor throws when finalizing twice")
  func decompressorThrowsOnDoubleFinalize() async throws {
    let decompressor = try LZMADecompressor()
    let input = Data("Hello".utf8)
    let compressed = try input.lzmaCompressed()

    _ = try await decompressor.decompress(compressed)
    _ = try await decompressor.finalize()

    await #expect(throws: LZMAError.streamAlreadyFinalized) {
      try await decompressor.finalize()
    }
  }
}
