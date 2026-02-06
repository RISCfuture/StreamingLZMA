/// Configuration options for XZ compression and decompression operations.
///
/// XZ provides more configuration options than raw LZMA, including compression
/// presets (0-9) and integrity check types.
public struct XZConfiguration: Sendable, Hashable {
  // MARK: - Type Properties

  /// Default configuration with medium (64 KB) buffer size, preset 6, CRC64 check.
  public static let `default` = Self()

  /// Compact configuration with small (16 KB) buffer size for memory-constrained environments.
  public static let compact = Self(bufferSize: .small)

  /// High throughput configuration with extra large (1 MB) buffer size for maximum performance.
  public static let highThroughput = Self(bufferSize: .extraLarge)

  /// Fast compression configuration with preset 0 for speed over compression ratio.
  public static let fast = Self(preset: 0)

  /// Best compression configuration with preset 9 for maximum compression ratio.
  public static let best = Self(preset: 9)

  // MARK: - Instance Properties

  /// The buffer size to use for streaming operations.
  public var bufferSize: BufferSize

  /// Compression preset level (0-9).
  /// - 0: Fastest compression, largest output
  /// - 6: Default, good balance
  /// - 9: Best compression, slowest
  public var preset: UInt32

  /// Integrity check type for compressed data.
  public var check: Check

  // MARK: - Initializers

  /// Creates a configuration with the specified options.
  /// - Parameters:
  ///   - bufferSize: The buffer size to use for streaming operations.
  ///   - preset: Compression preset level (0-9). Default is 6.
  ///   - check: Integrity check type. Default is CRC64.
  public init(bufferSize: BufferSize = .medium, preset: UInt32 = 6, check: Check = .crc64) {
    self.bufferSize = bufferSize
    self.preset = min(preset, 9)  // Clamp to valid range
    self.check = check
  }

  // MARK: - Nested Types

  /// Predefined buffer sizes for different use cases.
  public enum BufferSize: Sendable, Hashable {
    /// 16 KB buffer - suitable for memory-constrained environments
    case small

    /// 64 KB buffer - default, balanced for most use cases
    case medium

    /// 256 KB buffer - suitable for larger files
    case large

    /// 1 MB buffer - optimized for high throughput with large files
    case extraLarge

    /// Custom buffer size in bytes
    case custom(Int)

    /// The size in bytes for this buffer configuration.
    public var bytes: Int {
      switch self {
        case .small:
          return 16 * 1024  // 16 KB
        case .medium:
          return 64 * 1024  // 64 KB
        case .large:
          return 256 * 1024  // 256 KB
        case .extraLarge:
          return 1024 * 1024  // 1 MB
        case .custom(let size):
          return size
      }
    }
  }

  /// Integrity check types for XZ streams.
  public enum Check: UInt32, Sendable, Hashable {
    /// No integrity check
    case none = 0
    /// CRC32 (4 bytes)
    case crc32 = 1
    /// CRC64 (8 bytes) - default, good balance of speed and reliability
    case crc64 = 4
    /// SHA-256 (32 bytes) - strongest but slowest
    case sha256 = 10
  }
}
