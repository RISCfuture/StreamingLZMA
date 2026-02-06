import Foundation
import Testing
@testable import StreamingLZMAXZ

@Suite("XZCompressor Tests")
struct XZCompressorTests {
  @Test("Compressor can be reset")
  func compressorReset() async throws {
    let compressor = try XZCompressor()
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
    let compressor = try XZCompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    // Should throw on subsequent operations
    await #expect(throws: XZError.streamAlreadyFinalized) {
      try await compressor.compress(input)
    }
  }

  @Test("Compressor throws when finalizing twice")
  func compressorThrowsOnDoubleFinalize() async throws {
    let compressor = try XZCompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    await #expect(throws: XZError.streamAlreadyFinalized) {
      try await compressor.finalize()
    }
  }
}
