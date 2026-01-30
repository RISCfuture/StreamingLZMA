import Foundation

/// A streaming LZMA compressor that processes data incrementally.
///
/// `LZMACompressor` is an actor that provides compile-time data race safety.
/// All methods are implicitly `async` when called from outside the actor.
///
/// ## Usage
///
/// ```swift
/// let compressor = try LZMACompressor()
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
/// For synchronous one-shot compression, use the `Data.lzmaCompressed()` extension instead.
public actor LZMACompressor {
  private var stream: LZMAStream
  private let configuration: LZMAConfiguration

  /// Creates a new LZMA compressor.
  /// - Parameter configuration: The compression configuration to use.
  /// - Throws: ``LZMAError/streamInitializationFailed`` if the compressor cannot be initialized.
  public init(configuration: LZMAConfiguration = .default) throws(LZMAError) {
    self.configuration = configuration
    self.stream = try LZMAStream(
      direction: .compress,
      bufferSize: configuration.bufferSize.bytes
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
  /// - Throws: `LZMAError` if compression fails.
  public func compress(_ data: Data) throws(LZMAError) -> Data {
    try stream.process(data)
  }

  /// Finalizes compression and returns any remaining compressed data.
  ///
  /// This method must be called after all input has been processed to ensure
  /// the complete compressed output is produced.
  ///
  /// - Returns: Any remaining compressed data.
  /// - Throws: `LZMAError` if finalization fails.
  public func finalize() throws(LZMAError) -> Data {
    try stream.finalize()
  }

  /// Resets the compressor for reuse with new data.
  ///
  /// After calling this method, the compressor can be used to compress
  /// a new data stream.
  ///
  /// - Throws: ``LZMAError/streamInitializationFailed`` if reset fails.
  public func reset() throws(LZMAError) {
    try stream.reset()
  }
}
