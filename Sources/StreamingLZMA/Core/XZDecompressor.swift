import Foundation

/// A streaming XZ decompressor that processes data incrementally.
///
/// `XZDecompressor` is an actor that provides compile-time data race safety.
/// All methods are implicitly `async` when called from outside the actor.
///
/// ## Usage
///
/// ```swift
/// let decompressor = try XZDecompressor()
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
/// For synchronous one-shot decompression, use the `Data.xzDecompressed()` extension instead.
public actor XZDecompressor {
  private var stream: XZStream
  private let configuration: XZConfiguration

  /// Creates a new XZ decompressor.
  /// - Parameter configuration: The decompression configuration to use.
  /// - Throws: ``XZError/streamInitializationFailed`` if the decompressor cannot be initialized.
  public init(configuration: XZConfiguration = .default) throws(XZError) {
    self.configuration = configuration
    self.stream = try XZStream(
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
  /// - Throws: `XZError` if decompression fails (e.g., corrupted data).
  public func decompress(_ data: Data) throws(XZError) -> Data {
    try stream.process(data)
  }

  /// Finalizes decompression and returns any remaining decompressed data.
  ///
  /// This method must be called after all compressed input has been processed
  /// to ensure the complete decompressed output is produced.
  ///
  /// - Returns: Any remaining decompressed data.
  /// - Throws: `XZError` if finalization fails or data is incomplete.
  public func finalize() throws(XZError) -> Data {
    try stream.finalize()
  }

  /// Resets the decompressor for reuse with new data.
  ///
  /// After calling this method, the decompressor can be used to decompress
  /// a new data stream.
  ///
  /// - Throws: ``XZError/streamInitializationFailed`` if reset fails.
  public func reset() throws(XZError) {
    try stream.reset()
  }
}
