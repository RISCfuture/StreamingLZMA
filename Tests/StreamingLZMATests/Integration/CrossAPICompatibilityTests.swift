import Testing
import Foundation
@testable import StreamingLZMA

@Suite("Cross-API Compatibility Tests")
struct CrossAPICompatibilityTests {
  // MARK: - Raw Stream API Matrix Tests

  /// All raw stream APIs (non-file-format) that should interoperate
  static let rawStreamAPIs: [CompressionAPI] = [
    .dataExtension,
    .streamingCompressor,
    .fileHandle,
    .asyncSequenceData,
    .asyncSequenceBytes,
    .inputStream
  ]

  /// File format APIs that should interoperate
  static let fileFormatAPIs: [CompressionAPI] = [
    .dataExtensionFile,
    .fileHandleFile
  ]

  @Test("Raw stream APIs: full compatibility matrix with small data")
  func rawStreamMatrixSmall() async throws {
    let original = Data("Hello, cross-API compatibility test!".utf8)

    for compressAPI in Self.rawStreamAPIs {
      let compressed = try await compress(data: original, using: compressAPI)

      for decompressAPI in Self.rawStreamAPIs {
        let decompressed = try await decompress(data: compressed, using: decompressAPI)
        #expect(
          decompressed == original,
          "Failed: compress(\(compressAPI)) -> decompress(\(decompressAPI))"
        )
      }
    }
  }

  @Test("Raw stream APIs: full compatibility matrix with medium data")
  func rawStreamMatrixMedium() async throws {
    let original = Data((0..<10000).map { UInt8($0 & 0xFF) })

    for compressAPI in Self.rawStreamAPIs {
      let compressed = try await compress(data: original, using: compressAPI)

      for decompressAPI in Self.rawStreamAPIs {
        let decompressed = try await decompress(data: compressed, using: decompressAPI)
        #expect(
          decompressed == original,
          "Failed: compress(\(compressAPI)) -> decompress(\(decompressAPI))"
        )
      }
    }
  }

  @Test("File format APIs: compatibility matrix")
  func fileFormatMatrix() async throws {
    let original = Data("File format compatibility test data.".utf8)

    for compressAPI in Self.fileFormatAPIs {
      let compressed = try await compress(data: original, using: compressAPI)

      for decompressAPI in Self.fileFormatAPIs {
        let decompressed = try await decompress(data: compressed, using: decompressAPI)
        #expect(
          decompressed == original,
          "Failed: compress(\(compressAPI)) -> decompress(\(decompressAPI))"
        )
      }
    }
  }

  // MARK: - Size Variations Across APIs

  @Test("Size variations: 100 bytes across all raw APIs")
  func sizeVariations100B() async throws {
    try await verifySizeAcrossAPIs(size: 100)
  }

  @Test("Size variations: 1KB across all raw APIs")
  func sizeVariations1KB() async throws {
    try await verifySizeAcrossAPIs(size: 1024)
  }

  @Test("Size variations: 10KB across all raw APIs")
  func sizeVariations10KB() async throws {
    try await verifySizeAcrossAPIs(size: 10 * 1024)
  }

  @Test("Size variations: 100KB across all raw APIs")
  func sizeVariations100KB() async throws {
    try await verifySizeAcrossAPIs(size: 100 * 1024)
  }

  private func verifySizeAcrossAPIs(size: Int) async throws {
    let original = Data((0..<size).map { UInt8($0 & 0xFF) })

    for api in Self.rawStreamAPIs {
      let compressed = try await compress(data: original, using: api)
      let decompressed = try await decompress(data: compressed, using: api)
      #expect(decompressed == original, "Failed with API \(api) at size \(size)")
    }
  }

  // MARK: - Specific API Pair Tests

  @Test("Specific pair: Data extension -> FileHandle")
  func dataToFileHandle() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    let compressed = try await compress(data: original, using: .dataExtension)
    let decompressed = try await decompress(data: compressed, using: .fileHandle)

    #expect(decompressed == original)
  }

  @Test("Specific pair: FileHandle -> Data extension")
  func fileHandleToData() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    let compressed = try await compress(data: original, using: .fileHandle)
    let decompressed = try await decompress(data: compressed, using: .dataExtension)

    #expect(decompressed == original)
  }

  @Test("Specific pair: InputStream -> AsyncSequence<Data>")
  func inputStreamToAsyncData() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    let compressed = try await compress(data: original, using: .inputStream)
    let decompressed = try await decompress(data: compressed, using: .asyncSequenceData)

    #expect(decompressed == original)
  }

  @Test("Specific pair: AsyncSequence<UInt8> -> Streaming Compressor")
  func asyncBytesToStreaming() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    let compressed = try await compress(data: original, using: .asyncSequenceBytes)
    let decompressed = try await decompress(data: compressed, using: .streamingCompressor)

    #expect(decompressed == original)
  }

  @Test("Specific pair: Streaming Compressor -> InputStream")
  func streamingToInputStream() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    let compressed = try await compress(data: original, using: .streamingCompressor)
    let decompressed = try await decompress(data: compressed, using: .inputStream)

    #expect(decompressed == original)
  }

  @Test("Specific pair: File format Data -> FileHandle")
  func fileFormatDataToFileHandle() async throws {
    let original = Data("File format cross-API test.".utf8)

    let compressed = try await compress(data: original, using: .dataExtensionFile)
    let decompressed = try await decompress(data: compressed, using: .fileHandleFile)

    #expect(decompressed == original)
  }

  @Test("Specific pair: File format FileHandle -> Data")
  func fileFormatFileHandleToData() async throws {
    let original = Data("Reverse file format cross-API test.".utf8)

    let compressed = try await compress(data: original, using: .fileHandleFile)
    let decompressed = try await decompress(data: compressed, using: .dataExtensionFile)

    #expect(decompressed == original)
  }

  // MARK: - Configuration Independence

  @Test("Configuration: compress with small buffer, decompress with large")
  func configSmallToLarge() async throws {
    let original = Data((0..<50000).map { UInt8($0 & 0xFF) })

    let compressed = try await compress(
      data: original,
      using: .dataExtension,
      configuration: .compact  // 16KB buffer
    )
    let decompressed = try await decompress(
      data: compressed,
      using: .dataExtension,
      configuration: .highThroughput  // 1MB buffer
    )

    #expect(decompressed == original)
  }

  @Test("Configuration: compress with large buffer, decompress with small")
  func configLargeToSmall() async throws {
    let original = Data((0..<50000).map { UInt8($0 & 0xFF) })

    let compressed = try await compress(
      data: original,
      using: .dataExtension,
      configuration: .highThroughput  // 1MB buffer
    )
    let decompressed = try await decompress(
      data: compressed,
      using: .dataExtension,
      configuration: .compact  // 16KB buffer
    )

    #expect(decompressed == original)
  }

  @Test("Configuration: mixed APIs with different configs")
  func configMixedAPIs() async throws {
    let original = Data((0..<20000).map { UInt8($0 & 0xFF) })

    // Compress with streaming using small buffer
    let compressed = try await compress(
      data: original,
      using: .streamingCompressor,
      configuration: .compact
    )

    // Decompress with FileHandle using large buffer
    let decompressed = try await decompress(
      data: compressed,
      using: .fileHandle,
      configuration: .highThroughput
    )

    #expect(decompressed == original)
  }

  // MARK: - Concurrent API Usage

  @Test("Concurrent: multiple APIs compressing same data simultaneously")
  func concurrentCompression() async throws {
    let original = Data((0..<5000).map { UInt8($0 & 0xFF) })

    // Compress with multiple APIs concurrently
    async let compressed1 = compress(data: original, using: .dataExtension)
    async let compressed2 = compress(data: original, using: .streamingCompressor)
    async let compressed3 = compress(data: original, using: .fileHandle)

    let (c1, c2, c3) = try await (compressed1, compressed2, compressed3)

    // All should produce valid compressed data that decompresses to original
    let d1 = try await decompress(data: c1, using: .dataExtension)
    let d2 = try await decompress(data: c2, using: .dataExtension)
    let d3 = try await decompress(data: c3, using: .dataExtension)

    #expect(d1 == original)
    #expect(d2 == original)
    #expect(d3 == original)
  }

  @Test("Concurrent: different data through different APIs")
  func concurrentDifferentData() async throws {
    let data1 = Data("First piece of data".utf8)
    let data2 = Data("Second piece of data".utf8)
    let data3 = Data("Third piece of data".utf8)

    async let result1 = roundTrip(
      data1,
      compressAPI: .dataExtension,
      decompressAPI: .streamingCompressor
    )
    async let result2 = roundTrip(
      data2,
      compressAPI: .fileHandle,
      decompressAPI: .asyncSequenceData
    )
    async let result3 = roundTrip(data3, compressAPI: .inputStream, decompressAPI: .dataExtension)

    let (r1, r2, r3) = try await (result1, result2, result3)

    #expect(r1 == data1)
    #expect(r2 == data2)
    #expect(r3 == data3)
  }

  private func roundTrip(
    _ data: Data,
    compressAPI: CompressionAPI,
    decompressAPI: CompressionAPI
  ) async throws -> Data {
    let compressed = try await compress(data: data, using: compressAPI)
    return try await decompress(data: compressed, using: decompressAPI)
  }
}
