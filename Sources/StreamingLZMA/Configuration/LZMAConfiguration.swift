/// Configuration options for LZMA compression and decompression operations.
///
/// Apple's Compression framework uses fixed LZMA compression level 6 and does not
/// expose dictionary size or other algorithm parameters. Configuration is limited
/// to buffer management.
public struct LZMAConfiguration: Sendable, Hashable {
  // MARK: - Type Properties

  /// Default configuration with medium (64 KB) buffer size.
  public static let `default` = Self(bufferSize: .medium)

  /// Compact configuration with small (16 KB) buffer size for memory-constrained environments.
  public static let compact = Self(bufferSize: .small)

  /// High throughput configuration with extra large (1 MB) buffer size for maximum performance.
  public static let highThroughput = Self(bufferSize: .extraLarge)

  // MARK: - Instance Properties

  /// The buffer size to use for streaming operations.
  public var bufferSize: BufferSize

  // MARK: - Initializers

  /// Creates a configuration with the specified buffer size.
  /// - Parameter bufferSize: The buffer size to use for streaming operations.
  public init(bufferSize: BufferSize) {
    self.bufferSize = bufferSize
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
}
