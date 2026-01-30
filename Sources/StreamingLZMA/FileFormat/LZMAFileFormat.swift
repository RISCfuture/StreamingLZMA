import Foundation

/// Constants and utilities for the .lzma file format.
///
/// The .lzma file format (also known as LZMA alone or legacy LZMA format) uses a
/// 13-byte header followed by the compressed data stream.
public enum LZMAFileFormat {
  /// Size of the .lzma file header in bytes.
  public static let headerSize = 13

  /// Default properties byte value: lc=3, lp=0, pb=2.
  /// This is encoded as: pb * 45 + lp * 9 + lc = 2 * 45 + 0 * 9 + 3 = 93 = 0x5D
  public static let defaultProperties: UInt8 = 0x5D

  /// Default dictionary size used by Apple's Compression framework (8 MB).
  public static let defaultDictionarySize: UInt32 = 8_388_608

  /// Value indicating unknown uncompressed size.
  public static let unknownSize = UInt64.max
}
