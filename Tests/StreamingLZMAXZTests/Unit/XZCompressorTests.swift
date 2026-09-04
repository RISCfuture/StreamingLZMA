import Foundation
import Testing
@testable import StreamingLZMAXZ

@Suite
struct `XZCompressor Tests` {
  @Test
  func `Compressor can be reset`() async throws {
    let compressor = try XZCompressor()
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
    let compressor = try XZCompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    // Should throw on subsequent operations
    await #expect(throws: XZError.streamAlreadyFinalized) {
      try await compressor.compress(input)
    }
  }

  @Test
  func `Compressor throws when finalizing twice`() async throws {
    let compressor = try XZCompressor()
    let input = Data("Hello".utf8)

    _ = try await compressor.compress(input)
    _ = try await compressor.finalize()

    await #expect(throws: XZError.streamAlreadyFinalized) {
      try await compressor.finalize()
    }
  }
}
