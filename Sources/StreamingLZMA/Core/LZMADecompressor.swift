import Foundation

/// A streaming LZMA decompressor that processes data incrementally.
///
/// `LZMADecompressor` is an actor that provides compile-time data race safety.
/// All methods are implicitly `async` when called from outside the actor.
///
/// ## Usage
///
/// ```swift
/// let decompressor = try LZMADecompressor()
///
/// // Process data in chunks
/// var decompressed = Data()
/// for chunk in compressedChunks {
///     decompressed.append(try await decompressor.decompress(chunk))
/// }
///
/// // Finalize to get any remaining data
/// decompressed.append(try await decompressor.finalize())
/// ```
///
/// For synchronous one-shot decompression, use the `Data.lzmaDecompressed()` extension instead.
public actor LZMADecompressor {
  private var stream: LZMAStream
  private let configuration: LZMAConfiguration

  /// Creates a new LZMA decompressor.
  /// - Parameter configuration: The decompression configuration to use.
  /// - Throws: ``LZMAError/streamInitializationFailed`` if the decompressor cannot be initialized.
  public init(configuration: LZMAConfiguration = .default) throws(LZMAError) {
    self.configuration = configuration
    self.stream = try LZMAStream(
      direction: .decompress,
      bufferSize: configuration.bufferSize.bytes
    )
  }

  /// Decompresses input data and returns the decompressed output.
  ///
  /// This method processes the input incrementally. Call `finalize()` after all
  /// input has been processed to ensure the complete decompressed output is produced.
  ///
  /// - Parameter data: The compressed data to decompress.
  /// - Returns: Decompressed data.
  /// - Throws: `LZMAError` if decompression fails (e.g., corrupted data).
  public func decompress(_ data: Data) throws(LZMAError) -> Data {
    try stream.process(data)
  }

  /// Finalizes decompression and returns any remaining decompressed data.
  ///
  /// This method must be called after all compressed input has been processed
  /// to ensure the complete decompressed output is produced.
  ///
  /// - Returns: Any remaining decompressed data.
  /// - Throws: `LZMAError` if finalization fails or data is incomplete.
  public func finalize() throws(LZMAError) -> Data {
    try stream.finalize()
  }

  /// Resets the decompressor for reuse with new data.
  ///
  /// After calling this method, the decompressor can be used to decompress
  /// a new data stream.
  ///
  /// - Throws: ``LZMAError/streamInitializationFailed`` if reset fails.
  public func reset() throws(LZMAError) {
    try stream.reset()
  }
}
