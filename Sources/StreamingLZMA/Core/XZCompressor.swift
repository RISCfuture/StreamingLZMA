import Foundation

/// A streaming XZ compressor that processes data incrementally.
///
/// `XZCompressor` is an actor that provides compile-time data race safety.
/// All methods are implicitly `async` when called from outside the actor.
///
/// ## Usage
///
/// ```swift
/// let compressor = try XZCompressor()
///
/// // Process data in chunks
/// var compressed = Data()
/// for chunk in dataChunks {
///     compressed.append(try await compressor.compress(chunk))
/// }
///
/// // Finalize to get any remaining data
/// compressed.append(try await compressor.finalize())
/// ```
///
/// For synchronous one-shot compression, use the `Data.xzCompressed()` extension instead.
public actor XZCompressor {
  private var stream: XZStream
  private let configuration: XZConfiguration

  /// Creates a new XZ compressor.
  /// - Parameter configuration: The compression configuration to use.
  /// - Throws: ``XZError/streamInitializationFailed`` if the compressor cannot be initialized.
  public init(configuration: XZConfiguration = .default) throws(XZError) {
    self.configuration = configuration
    self.stream = try XZStream(
      direction: .compress,
      bufferSize: configuration.bufferSize.bytes,
      preset: configuration.preset,
      check: configuration.check
    )
  }

  /// Compresses input data and returns the compressed output.
  ///
  /// This method processes the input incrementally. The returned data may be empty
  /// if the compressor is buffering input. Call `finalize()` after all input has
  /// been processed to flush any remaining data.
  ///
  /// - Parameter data: The data to compress.
  /// - Returns: Compressed data (may be empty if buffering).
  /// - Throws: `XZError` if compression fails.
  public func compress(_ data: Data) throws(XZError) -> Data {
    try stream.process(data)
  }

  /// Finalizes compression and returns any remaining compressed data.
  ///
  /// This method must be called after all input has been processed to ensure
  /// the complete compressed output is produced.
  ///
  /// - Returns: Any remaining compressed data.
  /// - Throws: `XZError` if finalization fails.
  public func finalize() throws(XZError) -> Data {
    try stream.finalize()
  }

  /// Resets the compressor for reuse with new data.
  ///
  /// After calling this method, the compressor can be used to compress
  /// a new data stream.
  ///
  /// - Throws: ``XZError/streamInitializationFailed`` if reset fails.
  public func reset() throws(XZError) {
    try stream.reset()
  }
}
