import Testing
import Foundation
@testable import StreamingLZMA

@Suite
struct `Random Data Tests` {
  // MARK: - Cryptographically Random Data Tests

  @Test
  func `Crypto random: small data (100 bytes)`() throws {
    let original = randomData(count: 100)
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Crypto random: medium data (10KB)`() throws {
    let original = randomData(count: 10 * 1024)
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Crypto random: large data (100KB)`() throws {
    let original = randomData(count: 100 * 1024)
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  // MARK: - Expansion Tests (Data That Doesn't Compress)

  @Test
  func `Expansion: random data may expand slightly when compressed`() throws {
    // Cryptographically random data has maximum entropy and cannot be compressed
    // LZMA will add overhead, causing slight expansion
    let original = randomData(count: 1000)
    let compressed = try original.lzmaCompressed()

    // Random data typically expands slightly (up to ~1% + fixed overhead)
    // We just verify round-trip works regardless of size
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Expansion: already compressed data (double compression)`() throws {
    // First compress some data
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    let compressed1 = try original.lzmaCompressed()

    // Compress again - this should work but won't compress further
    let compressed2 = try compressed1.lzmaCompressed()

    // Verify both levels decompress correctly
    let decompressed2 = try compressed2.lzmaDecompressed()
    #expect(decompressed2 == compressed1)

    let decompressed1 = try decompressed2.lzmaDecompressed()
    #expect(decompressed1 == original)
  }

  @Test
  func `Expansion: triple compression`() throws {
    let original = Data("Hello, triple compression test!".utf8)

    let c1 = try original.lzmaCompressed()
    let c2 = try c1.lzmaCompressed()
    let c3 = try c2.lzmaCompressed()

    let d3 = try c3.lzmaDecompressed()
    let d2 = try d3.lzmaDecompressed()
    let d1 = try d2.lzmaDecompressed()

    #expect(d1 == original)
  }

  // MARK: - Seeded Random Tests (Reproducibility)

  @Test
  func `Seeded random: reproducible data generation`() throws {
    let seed: UInt64 = 12345

    // Generate data with same seed twice
    let data1 = seededRandomData(count: 1000, seed: seed)
    let data2 = seededRandomData(count: 1000, seed: seed)

    #expect(data1 == data2, "Same seed should produce same data")

    // Different seed should produce different data
    let data3 = seededRandomData(count: 1000, seed: seed + 1)
    #expect(data1 != data3, "Different seed should produce different data")
  }

  @Test
  func `Seeded random: round-trip with various seeds`() throws {
    let seeds: [UInt64] = [0, 1, 42, 12345, 999999, .max]

    for seed in seeds {
      let original = seededRandomData(count: 5000, seed: seed)
      let compressed = try original.lzmaCompressed()
      let decompressed = try compressed.lzmaDecompressed()
      #expect(decompressed == original, "Failed with seed \(seed)")
    }
  }

  // MARK: - Mixed Compressibility Tests

  @Test
  func `Mixed compressibility: alternating patterns`() throws {
    let original = mixedCompressibilityData(count: 10000, seed: 42)
    let compressed = try original.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Mixed compressibility: various sizes`() throws {
    for size in [100, 1000, 5000, 20000] {
      let original = mixedCompressibilityData(count: size, seed: 0xDEADBEEF)
      let compressed = try original.lzmaCompressed()
      let decompressed = try compressed.lzmaDecompressed()
      #expect(decompressed == original, "Failed at size \(size)")
    }
  }

  // MARK: - Streaming with Random Chunk Sizes

  @Test
  func `Streaming: random chunk sizes for compression`() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    var rng = SeededRandomNumberGenerator(seed: 98765)

    let compressor = try LZMACompressor()
    var compressed = Data()
    var offset = 0

    while offset < original.count {
      // Random chunk size between 1 and 500
      let maxChunk = min(Int(rng.next() % 500) + 1, original.count - offset)
      let chunk = original[offset..<(offset + maxChunk)]
      compressed.append(try await compressor.compress(Data(chunk)))
      offset += maxChunk
    }
    compressed.append(try await compressor.finalize())

    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == original)
  }

  @Test
  func `Streaming: random chunk sizes for decompression`() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })
    let compressed = try original.lzmaCompressed()
    var rng = SeededRandomNumberGenerator(seed: 54321)

    let decompressor = try LZMADecompressor()
    var decompressed = Data()
    var offset = 0

    while offset < compressed.count {
      // Random chunk size between 1 and 200
      let maxChunk = min(Int(rng.next() % 200) + 1, compressed.count - offset)
      let chunk = compressed[offset..<(offset + maxChunk)]
      decompressed.append(try await decompressor.decompress(Data(chunk)))
      offset += maxChunk
    }
    decompressed.append(try await decompressor.finalize())

    #expect(decompressed == original)
  }

  @Test
  func `Streaming: random chunks for both compression and decompression`() async throws {
    let original = seededRandomData(count: 5000, seed: 11111)
    var rng = SeededRandomNumberGenerator(seed: 22222)

    // Random chunk compression
    let compressor = try LZMACompressor()
    var compressed = Data()
    var offset = 0

    while offset < original.count {
      let maxChunk = min(Int(rng.next() % 300) + 1, original.count - offset)
      let chunk = original[offset..<(offset + maxChunk)]
      compressed.append(try await compressor.compress(Data(chunk)))
      offset += maxChunk
    }
    compressed.append(try await compressor.finalize())

    // Random chunk decompression
    let decompressor = try LZMADecompressor()
    var decompressed = Data()
    offset = 0

    while offset < compressed.count {
      let maxChunk = min(Int(rng.next() % 150) + 1, compressed.count - offset)
      let chunk = compressed[offset..<(offset + maxChunk)]
      decompressed.append(try await decompressor.decompress(Data(chunk)))
      offset += maxChunk
    }
    decompressed.append(try await decompressor.finalize())

    #expect(decompressed == original)
  }

  // MARK: - Adversarial Patterns

  @Test
  func `Adversarial: worst-case repeating pattern`() throws {
    // Create a pattern that's repetitive but with slight variations
    // This tests the LZMA dictionary matching
    var data = Data()
    for i in 0..<1000 {
      data.append(contentsOf: "ABCDEFGH\(i)".utf8)
    }

    let compressed = try data.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == data)
  }

  @Test
  func `Adversarial: alternating bytes`() throws {
    var data = Data()
    for _ in 0..<5000 {
      data.append(0xAA)
      data.append(0x55)
    }

    let compressed = try data.lzmaCompressed()
    let decompressed = try compressed.lzmaDecompressed()
    #expect(decompressed == data)
  }
}
