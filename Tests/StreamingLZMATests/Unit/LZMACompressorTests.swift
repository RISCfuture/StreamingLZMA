import Testing
@testable import StreamingLZMA

@Suite("LZMACompressor Tests")
struct LZMACompressorTests {
  @Test("Compressor can be reset")
  func compressorReset() async throws {
    let compressor = try LZMACompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    // Reset and use again
    try await compressor.reset()

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()
  }

  @Test("Compressor throws when processing after finalize")
  func compressorThrowsAfterFinalize() async throws {
    let compressor = try LZMACompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    // Should throw on subsequent operations
    await #expect(throws: LZMAError.streamAlreadyFinalized) {
      try await compressor.compress(input)
    }
  }

  @Test("Compressor throws when finalizing twice")
  func compressorThrowsOnDoubleFinalize() async throws {
    let compressor = try LZMACompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    await #expect(throws: LZMAError.streamAlreadyFinalized) {
      try await compressor.finalize()
    }
  }
}
