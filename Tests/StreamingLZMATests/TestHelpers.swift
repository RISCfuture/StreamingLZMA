import Foundation
import Security
@testable import StreamingLZMA

// MARK: - Random Data Generation

/// Generates cryptographically random data.
/// - Parameter count: Number of random bytes to generate.
/// - Returns: Data containing cryptographically random bytes.
func randomData(count: Int) -> Data {
  var data = Data(count: count)
  _ = data.withUnsafeMutableBytes { buffer in
    SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
  }
  return data
}

/// A seeded pseudo-random number generator for reproducible tests.
///
/// Uses the xorshift64 algorithm for fast, deterministic random numbers.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
  private var state: UInt64

  /// Creates a generator with the specified seed.
  /// - Parameter seed: The seed value. A seed of 0 is treated as 1.
  init(seed: UInt64) {
    self.state = seed == 0 ? 1 : seed
  }

  mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}

/// Generates deterministic pseudo-random data using a seeded generator.
/// - Parameters:
///   - count: Number of bytes to generate.
///   - seed: The seed for reproducible output.
/// - Returns: Data containing pseudo-random bytes.
func seededRandomData(count: Int, seed: UInt64) -> Data {
  var rng = SeededRandomNumberGenerator(seed: seed)
  var bytes = [UInt8]()
  bytes.reserveCapacity(count)

  while bytes.count < count {
    let value = rng.next()
    for shift in stride(from: 0, to: 64, by: 8) {
      if bytes.count >= count { break }
      bytes.append(UInt8(truncatingIfNeeded: value >> shift))
    }
  }

  return Data(bytes)
}

/// Generates data with mixed compressibility patterns.
/// - Parameters:
///   - count: Total number of bytes to generate.
///   - seed: The seed for reproducible output.
/// - Returns: Data with alternating compressible and random sections.
func mixedCompressibilityData(count: Int, seed: UInt64) -> Data {
  var rng = SeededRandomNumberGenerator(seed: seed)
  var data = Data()
  data.reserveCapacity(count)

  let sectionSize = max(count / 10, 1)
  var isCompressible = true

  while data.count < count {
    let remaining = count - data.count
    let thisSection = min(sectionSize, remaining)

    if isCompressible {
      // Highly compressible: repeating pattern
      let pattern = UInt8(truncatingIfNeeded: rng.next())
      data.append(contentsOf: repeatElement(pattern, count: thisSection))
    } else {
      // Low compressibility: pseudo-random data
      for _ in 0..<thisSection {
        data.append(UInt8(truncatingIfNeeded: rng.next()))
      }
    }

    isCompressible.toggle()
  }

  return data
}

// MARK: - Cross-API Compression Helpers

/// Enumeration of all available LZMA compression/decompression APIs.
enum CompressionAPI: String, CaseIterable, CustomStringConvertible {
  case dataExtension = "Data Extension"
  case dataExtensionFile = "Data Extension (File Format)"
  case streamingCompressor = "Streaming Compressor"
  case fileHandle = "FileHandle"
  case fileHandleFile = "FileHandle (File Format)"
  case asyncSequenceData = "AsyncSequence<Data>"
  case asyncSequenceBytes = "AsyncSequence<UInt8>"
  case inputStream = "InputStream"

  var description: String { rawValue }

  /// Whether this API uses the .lzma file format with header.
  var usesFileFormat: Bool {
    switch self {
      case .dataExtensionFile, .fileHandleFile:
        return true
      default:
        return false
    }
  }
}

/// Compresses data using the specified API.
/// - Parameters:
///   - data: The data to compress.
///   - api: The compression API to use.
///   - configuration: The compression configuration.
/// - Returns: The compressed data.
func compress(data: Data, using api: CompressionAPI, configuration: LZMAConfiguration = .default)
  async throws -> Data
{
  switch api {
    case .dataExtension:
      return try data.lzmaCompressed(configuration: configuration)

    case .dataExtensionFile:
      return try data.lzmaFileCompressed(configuration: configuration)

    case .streamingCompressor:
      let compressor = try LZMACompressor(configuration: configuration)
      var result = try await compressor.compress(data)
      result.append(try await compressor.finalize())
      return result

    case .fileHandle:
      return try await compressViaFileHandle(
        data: data,
        useFileFormat: false,
        configuration: configuration
      )

    case .fileHandleFile:
      return try await compressViaFileHandle(
        data: data,
        useFileFormat: true,
        configuration: configuration
      )

    case .asyncSequenceData:
      return try await compressViaAsyncSequenceData(data: data, configuration: configuration)

    case .asyncSequenceBytes:
      return try await compressViaAsyncSequenceBytes(data: data, configuration: configuration)

    case .inputStream:
      return try await compressViaInputStream(data: data, configuration: configuration)
  }
}

/// Decompresses data using the specified API.
/// - Parameters:
///   - data: The compressed data to decompress.
///   - api: The decompression API to use.
///   - configuration: The decompression configuration.
/// - Returns: The decompressed data.
func decompress(data: Data, using api: CompressionAPI, configuration: LZMAConfiguration = .default)
  async throws -> Data
{
  switch api {
    case .dataExtension:
      return try data.lzmaDecompressed(configuration: configuration)

    case .dataExtensionFile:
      return try data.lzmaFileDecompressed(configuration: configuration)

    case .streamingCompressor:
      let decompressor = try LZMADecompressor(configuration: configuration)
      var result = try await decompressor.decompress(data)
      result.append(try await decompressor.finalize())
      return result

    case .fileHandle:
      return try await decompressViaFileHandle(
        data: data,
        useFileFormat: false,
        configuration: configuration
      )

    case .fileHandleFile:
      return try await decompressViaFileHandle(
        data: data,
        useFileFormat: true,
        configuration: configuration
      )

    case .asyncSequenceData:
      return try await decompressViaAsyncSequenceData(data: data, configuration: configuration)

    case .asyncSequenceBytes:
      return try await decompressViaAsyncSequenceBytes(data: data, configuration: configuration)

    case .inputStream:
      return try await decompressViaInputStream(data: data, configuration: configuration)
  }
}

// MARK: - Private API Implementation Helpers

private func compressViaFileHandle(
  data: Data,
  useFileFormat: Bool,
  configuration: LZMAConfiguration
) throws -> Data {
  let tempDir = FileManager.default.temporaryDirectory
  let sourceURL = tempDir.appendingPathComponent("source_\(UUID().uuidString).bin")
  let compressedURL = tempDir.appendingPathComponent("compressed_\(UUID().uuidString).lzma")

  defer {
    try? FileManager.default.removeItem(at: sourceURL)
    try? FileManager.default.removeItem(at: compressedURL)
  }

  try data.write(to: sourceURL)
  FileManager.default.createFile(atPath: compressedURL.path, contents: nil)

  let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
  let compressedHandle = try FileHandle(forWritingTo: compressedURL)
  defer {
    try? sourceHandle.close()
    try? compressedHandle.close()
  }

  if useFileFormat {
    try sourceHandle.lzmaFileCompress(to: compressedHandle, configuration: configuration)
  } else {
    try sourceHandle.lzmaCompress(to: compressedHandle, configuration: configuration)
  }

  return try Data(contentsOf: compressedURL)
}

private func decompressViaFileHandle(
  data: Data,
  useFileFormat: Bool,
  configuration: LZMAConfiguration
) throws -> Data {
  let tempDir = FileManager.default.temporaryDirectory
  let compressedURL = tempDir.appendingPathComponent("compressed_\(UUID().uuidString).lzma")
  let decompressedURL = tempDir.appendingPathComponent("decompressed_\(UUID().uuidString).bin")

  defer {
    try? FileManager.default.removeItem(at: compressedURL)
    try? FileManager.default.removeItem(at: decompressedURL)
  }

  try data.write(to: compressedURL)
  FileManager.default.createFile(atPath: decompressedURL.path, contents: nil)

  let compressedHandle = try FileHandle(forReadingFrom: compressedURL)
  let decompressedHandle = try FileHandle(forWritingTo: decompressedURL)
  defer {
    try? compressedHandle.close()
    try? decompressedHandle.close()
  }

  if useFileFormat {
    try compressedHandle.lzmaFileDecompress(to: decompressedHandle, configuration: configuration)
  } else {
    try compressedHandle.lzmaDecompress(to: decompressedHandle, configuration: configuration)
  }

  return try Data(contentsOf: decompressedURL)
}

private func compressViaAsyncSequenceData(data: Data, configuration: LZMAConfiguration) async throws
  -> Data
{
  let chunks = stride(from: 0, to: data.count, by: configuration.bufferSize.bytes).map { start in
    let end = min(start + configuration.bufferSize.bytes, data.count)
    return data[start..<end]
  }

  let stream = AsyncStream<Data> { continuation in
    for chunk in chunks {
      continuation.yield(Data(chunk))
    }
    continuation.finish()
  }

  var result = Data()
  for try await chunk in stream.lzmaCompressed(configuration: configuration) {
    result.append(chunk)
  }
  return result
}

private func decompressViaAsyncSequenceData(data: Data, configuration: LZMAConfiguration)
  async throws -> Data
{
  let chunks = stride(from: 0, to: data.count, by: configuration.bufferSize.bytes).map { start in
    let end = min(start + configuration.bufferSize.bytes, data.count)
    return data[start..<end]
  }

  let stream = AsyncStream<Data> { continuation in
    for chunk in chunks {
      continuation.yield(Data(chunk))
    }
    continuation.finish()
  }

  var result = Data()
  for try await chunk in stream.lzmaDecompressed(configuration: configuration) {
    result.append(chunk)
  }
  return result
}

private func compressViaAsyncSequenceBytes(data: Data, configuration: LZMAConfiguration)
  async throws -> Data
{
  let stream = AsyncStream<UInt8> { continuation in
    for byte in data {
      continuation.yield(byte)
    }
    continuation.finish()
  }

  var result = Data()
  for try await chunk in stream.lzmaCompressed(configuration: configuration) {
    result.append(chunk)
  }
  return result
}

private func decompressViaAsyncSequenceBytes(data: Data, configuration: LZMAConfiguration)
  async throws -> Data
{
  let stream = AsyncStream<UInt8> { continuation in
    for byte in data {
      continuation.yield(byte)
    }
    continuation.finish()
  }

  var result = Data()
  for try await chunk in stream.lzmaDecompressed(configuration: configuration) {
    result.append(chunk)
  }
  return result
}

private func compressViaInputStream(data: Data, configuration: LZMAConfiguration) async throws
  -> Data
{
  let inputStream = InputStream(data: data)
  var result = Data()
  for try await chunk in inputStream.lzmaCompressedStream(configuration: configuration) {
    result.append(chunk)
  }
  return result
}

private func decompressViaInputStream(data: Data, configuration: LZMAConfiguration) async throws
  -> Data
{
  let inputStream = InputStream(data: data)
  var result = Data()
  for try await chunk in inputStream.lzmaDecompressedStream(configuration: configuration) {
    result.append(chunk)
  }
  return result
}

// MARK: - Chunked Processing Helpers

/// Splits data into chunks of the specified size.
/// - Parameters:
///   - data: The data to split.
///   - chunkSize: The size of each chunk.
/// - Returns: An array of data chunks.
func splitIntoChunks(_ data: Data, chunkSize: Int) -> [Data] {
  stride(from: 0, to: data.count, by: chunkSize).map { start in
    let end = min(start + chunkSize, data.count)
    return Data(data[start..<end])
  }
}

/// Compresses data by processing it in chunks of the specified size.
/// - Parameters:
///   - data: The data to compress.
///   - chunkSize: The size of each input chunk.
///   - configuration: The compression configuration.
/// - Returns: The compressed data.
func compressInChunks(_ data: Data, chunkSize: Int, configuration: LZMAConfiguration = .default)
  async throws -> Data
{
  let compressor = try LZMACompressor(configuration: configuration)
  var result = Data()

  for chunk in splitIntoChunks(data, chunkSize: chunkSize) {
    result.append(try await compressor.compress(chunk))
  }
  result.append(try await compressor.finalize())

  return result
}

/// Decompresses data by processing it in chunks of the specified size.
/// - Parameters:
///   - data: The compressed data to decompress.
///   - chunkSize: The size of each input chunk.
///   - configuration: The decompression configuration.
/// - Returns: The decompressed data.
func decompressInChunks(_ data: Data, chunkSize: Int, configuration: LZMAConfiguration = .default)
  async throws -> Data
{
  let decompressor = try LZMADecompressor(configuration: configuration)
  var result = Data()

  for chunk in splitIntoChunks(data, chunkSize: chunkSize) {
    result.append(try await decompressor.decompress(chunk))
  }
  result.append(try await decompressor.finalize())

  return result
}

// MARK: - Data Corruption Helpers

/// Corrupts data by flipping a single bit at the specified position.
/// - Parameters:
///   - data: The data to corrupt.
///   - byteIndex: The index of the byte to corrupt.
///   - bitIndex: The index of the bit to flip (0-7).
/// - Returns: A copy of the data with one bit flipped.
func flipBit(in data: Data, byteIndex: Int, bitIndex: Int) -> Data {
  var corrupted = data
  corrupted[byteIndex] ^= (1 << bitIndex)
  return corrupted
}

/// Corrupts data by replacing a byte at the specified position.
/// - Parameters:
///   - data: The data to corrupt.
///   - byteIndex: The index of the byte to replace.
///   - newValue: The new byte value.
/// - Returns: A copy of the data with one byte replaced.
func replaceByte(in data: Data, byteIndex: Int, newValue: UInt8) -> Data {
  var corrupted = data
  corrupted[byteIndex] = newValue
  return corrupted
}

/// Truncates data to the specified length.
/// - Parameters:
///   - data: The data to truncate.
///   - length: The new length.
/// - Returns: A copy of the data truncated to the specified length.
func truncate(_ data: Data, to length: Int) -> Data {
  Data(data.prefix(length))
}
