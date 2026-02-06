import Foundation

extension InputStream {
  // MARK: - Private Type Methods

  /// Processes XZ compression of an input stream.
  ///
  /// The `@concurrent` attribute ensures this function runs off the calling actor,
  /// making it suitable for blocking I/O operations.
  @concurrent
  private static func processXZCompression(
    _ wrapper: _XZUnsafeSendableInputStream,
    continuation: AsyncThrowingStream<Data, Error>.Continuation,
    configuration: XZConfiguration
  ) async {
    let stream = wrapper.stream
    do {
      let compressor = try XZCompressor(configuration: configuration)
      let bufferSize = configuration.bufferSize.bytes
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer { buffer.deallocate() }

      stream.open()
      defer { stream.close() }

      while stream.hasBytesAvailable {
        let bytesRead = stream.read(buffer, maxLength: bufferSize)

        if bytesRead < 0 {
          if let streamError = stream.streamError {
            continuation.finish(throwing: XZError.internalError("Stream error: \(streamError)"))
          } else {
            continuation.finish(throwing: XZError.processingFailed)
          }
          return
        }

        if bytesRead == 0 {
          break
        }

        let chunk = Data(bytes: buffer, count: bytesRead)
        let compressed = try await compressor.compress(chunk)
        if !compressed.isEmpty {
          continuation.yield(compressed)
        }
      }

      // Finalize
      let finalData = try await compressor.finalize()
      if !finalData.isEmpty {
        continuation.yield(finalData)
      }

      continuation.finish()
    } catch {
      continuation.finish(throwing: error)
    }
  }

  /// Processes XZ decompression of an input stream.
  ///
  /// The `@concurrent` attribute ensures this function runs off the calling actor,
  /// making it suitable for blocking I/O operations.
  @concurrent
  private static func processXZDecompression(
    _ wrapper: _XZUnsafeSendableInputStream,
    continuation: AsyncThrowingStream<Data, Error>.Continuation,
    configuration: XZConfiguration
  ) async {
    let stream = wrapper.stream
    do {
      let decompressor = try XZDecompressor(configuration: configuration)
      let bufferSize = configuration.bufferSize.bytes
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer { buffer.deallocate() }

      stream.open()
      defer { stream.close() }

      while stream.hasBytesAvailable {
        let bytesRead = stream.read(buffer, maxLength: bufferSize)

        if bytesRead < 0 {
          if let streamError = stream.streamError {
            continuation.finish(throwing: XZError.internalError("Stream error: \(streamError)"))
          } else {
            continuation.finish(throwing: XZError.processingFailed)
          }
          return
        }

        if bytesRead == 0 {
          break
        }

        let chunk = Data(bytes: buffer, count: bytesRead)
        let decompressed = try await decompressor.decompress(chunk)
        if !decompressed.isEmpty {
          continuation.yield(decompressed)
        }
      }

      // Finalize
      let finalData = try await decompressor.finalize()
      if !finalData.isEmpty {
        continuation.yield(finalData)
      }

      continuation.finish()
    } catch {
      continuation.finish(throwing: error)
    }
  }

  // MARK: - Instance Methods

  /// Returns an async stream of XZ compressed data chunks.
  ///
  /// This method reads from the input stream and produces compressed XZ data
  /// as an async throwing stream. Each element in the stream is a chunk of
  /// compressed data.
  ///
  /// - Parameter configuration: The compression configuration to use.
  /// - Returns: An async throwing stream of compressed data chunks.
  /// - Important: The caller must ensure this InputStream is not accessed elsewhere
  ///   while the returned stream is being consumed.
  public func xzCompressedStream(
    configuration: XZConfiguration = .default
  ) -> AsyncThrowingStream<Data, Error> {
    let stream = _XZUnsafeSendableInputStream(self)
    return AsyncThrowingStream { continuation in
      Task {
        await Self.processXZCompression(
          stream,
          continuation: continuation,
          configuration: configuration
        )
      }
    }
  }

  /// Returns an async stream of decompressed data chunks.
  ///
  /// This method reads XZ compressed data from the input stream and produces
  /// decompressed data as an async throwing stream.
  ///
  /// - Parameter configuration: The decompression configuration to use.
  /// - Returns: An async throwing stream of decompressed data chunks.
  /// - Important: The caller must ensure this InputStream is not accessed elsewhere
  ///   while the returned stream is being consumed.
  public func xzDecompressedStream(
    configuration: XZConfiguration = .default
  ) -> AsyncThrowingStream<Data, Error> {
    let stream = _XZUnsafeSendableInputStream(self)
    return AsyncThrowingStream { continuation in
      Task {
        await Self.processXZDecompression(
          stream,
          continuation: continuation,
          configuration: configuration
        )
      }
    }
  }
}

// MARK: - Internal

/// Wrapper to allow InputStream to cross isolation boundaries.
///
/// `InputStream` is not `Sendable` because it's a mutable Foundation class.
/// This wrapper uses `@unchecked Sendable` to allow capturing it in a `@Sendable`
/// closure (required by `Task`).
///
/// - Important: Safety is guaranteed by the API contract: callers must not access
///   the `InputStream` from outside the returned `AsyncThrowingStream` while it
///   is being consumed.
private struct _XZUnsafeSendableInputStream: @unchecked Sendable {
  let stream: InputStream

  init(_ stream: InputStream) {
    self.stream = stream
  }
}
