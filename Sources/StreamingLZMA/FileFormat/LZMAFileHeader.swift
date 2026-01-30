import Foundation

/// LZMA file header for CLI-compatible .lzma files.
///
/// The .lzma file format uses a 13-byte header:
/// - Byte 0: Properties byte (encodes lc, lp, pb)
/// - Bytes 1-4: Dictionary size (little-endian UInt32)
/// - Bytes 5-12: Uncompressed size (little-endian UInt64, -1 if unknown)
public struct LZMAFileHeader: Sendable, Hashable {
  // MARK: - Type Properties

  /// Default header with standard LZMA parameters and unknown size.
  ///
  /// Uses properties 0x5D (lc=3, lp=0, pb=2), 8 MB dictionary, and unknown size.
  public static let `default` = Self(
    properties: LZMAFileFormat.defaultProperties,
    dictionarySize: LZMAFileFormat.defaultDictionarySize,
    uncompressedSize: LZMAFileFormat.unknownSize
  )

  // MARK: - Instance Properties

  /// Properties byte encoding lc (literal context bits), lp (literal position bits),
  /// and pb (position bits) as: pb * 45 + lp * 9 + lc.
  public let properties: UInt8

  /// Dictionary size in bytes.
  public let dictionarySize: UInt32

  /// Uncompressed size in bytes, or UInt64.max if unknown.
  public let uncompressedSize: UInt64

  /// Decodes the properties byte into individual LZMA parameters.
  /// - Returns: A tuple of (lc, lp, pb) values.
  public var decodedProperties: (lc: Int, lp: Int, pb: Int) {
    let value = Int(properties),
      pb = value / 45,
      lp = (value % 45) / 9,
      lc = value % 9
    return (lc, lp, pb)
  }

  // MARK: - Initializers

  /// Creates a header with the specified parameters.
  /// - Parameters:
  ///   - properties: Properties byte encoding lc, lp, pb.
  ///   - dictionarySize: Dictionary size in bytes.
  ///   - uncompressedSize: Uncompressed size or UInt64.max if unknown.
  public init(properties: UInt8, dictionarySize: UInt32, uncompressedSize: UInt64) {
    self.properties = properties
    self.dictionarySize = dictionarySize
    self.uncompressedSize = uncompressedSize
  }

  /// Creates a header with known uncompressed size using default LZMA parameters.
  /// - Parameter uncompressedSize: The known uncompressed size in bytes.
  public init(uncompressedSize: UInt64) {
    self.properties = LZMAFileFormat.defaultProperties
    self.dictionarySize = LZMAFileFormat.defaultDictionarySize
    self.uncompressedSize = uncompressedSize
  }

  /// Parses a header from binary data.
  /// - Parameter data: The data to parse (must be at least 13 bytes).
  /// - Throws: ``LZMAError/corruptedData`` if the data is too short.
  public init(from data: Data) throws(LZMAError) {
    guard data.count >= LZMAFileFormat.headerSize else {
      throw .corruptedData
    }

    self.properties = data[data.startIndex]

    // Dictionary size (little-endian)
    self.dictionarySize = data.withUnsafeBytes { buffer in
      buffer.loadUnaligned(fromByteOffset: 1, as: UInt32.self).littleEndian
    }

    // Uncompressed size (little-endian)
    self.uncompressedSize = data.withUnsafeBytes { buffer in
      buffer.loadUnaligned(fromByteOffset: 5, as: UInt64.self).littleEndian
    }
  }

  // MARK: - Instance Methods

  /// Encodes the header to binary data.
  /// - Returns: A 13-byte Data containing the encoded header.
  public func encoded() -> Data {
    var data = Data(capacity: LZMAFileFormat.headerSize)

    // Properties byte
    data.append(properties)

    // Dictionary size (little-endian)
    var dictSize = dictionarySize.littleEndian
    withUnsafeBytes(of: &dictSize) { data.append(contentsOf: $0) }

    // Uncompressed size (little-endian)
    var uncSize = uncompressedSize.littleEndian
    withUnsafeBytes(of: &uncSize) { data.append(contentsOf: $0) }

    return data
  }
}
