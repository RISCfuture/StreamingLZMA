import Foundation
import Testing
@testable import StreamingLZMA

@Suite
struct `LZMADecompressor Tests` {
  @Test
  func `Decompressor can be reset`() async throws {
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

  @Test
  func `Decompressor throws when processing after finalize`() async throws {
    let decompressor = try LZMADecompressor()
    let input = Data("Hello".utf8)
    let compressed = try input.lzmaCompressed()

    _ = try await decompressor.decompress(compressed)
    _ = try await decompressor.finalize()

    await #expect(throws: LZMAError.streamAlreadyFinalized) {
      try await decompressor.decompress(compressed)
    }
  }

  @Test
  func `Decompressor throws when finalizing twice`() async throws {
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
