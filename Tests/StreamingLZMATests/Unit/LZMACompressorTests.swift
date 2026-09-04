import Foundation
import Testing
@testable import StreamingLZMA

@Suite
struct `LZMACompressor Tests` {
  @Test
  func `Compressor can be reset`() async throws {
    let compressor = try LZMACompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    // Reset and use again
    try await compressor.reset()

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()
  }

  @Test
  func `Compressor throws when processing after finalize`() async throws {
    let compressor = try LZMACompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    // Should throw on subsequent operations
    await #expect(throws: LZMAError.streamAlreadyFinalized) {
      try await compressor.compress(input)
    }
  }

  @Test
  func `Compressor throws when finalizing twice`() async throws {
    let compressor = try LZMACompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    await #expect(throws: LZMAError.streamAlreadyFinalized) {
      try await compressor.finalize()
    }
  }
}
