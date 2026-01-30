import Foundation

// MARK: - AsyncSequence where Element == UInt8

extension AsyncSequence where Element == UInt8, Self: Sendable {
  /// Returns an async stream of XZ compressed data chunks.
  ///
  /// This method consumes bytes from the async sequence and produces compressed
  /// XZ data as an async throwing stream.
  ///
  /// - Parameter configuration: The compression configuration to use.
  /// - Returns: An async throwing stream of compressed data chunks.
  public func xzCompressed(
    configuration: XZConfiguration = .default
  ) -> AsyncThrowingStream<Data, Error> {
    let sequence = self
    return AsyncThrowingStream { continuation in
      Task {
        do {
          let compressor = try XZCompressor(configuration: configuration)
          let bufferSize = configuration.bufferSize.bytes
          var buffer = Data()
          buffer.reserveCapacity(bufferSize)

          for try await byte in sequence {
            buffer.append(byte)

            if buffer.count >= bufferSize {
              let compressed = try await compressor.compress(buffer)
              if !compressed.isEmpty {
                continuation.yield(compressed)
              }
              buffer.removeAll(keepingCapacity: true)
            }
          }

          // Process any remaining bytes
          if !buffer.isEmpty {
            let compressed = try await compressor.compress(buffer)
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
        } catch let error as XZError {
          continuation.finish(throwing: error)
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  /// Returns an async stream of decompressed data chunks.
  ///
  /// This method consumes XZ compressed bytes from the async sequence and
  /// produces decompressed data as an async throwing stream.
  ///
  /// - Parameter configuration: The decompression configuration to use.
  /// - Returns: An async throwing stream of decompressed data chunks.
  public func xzDecompressed(
    configuration: XZConfiguration = .default
  ) -> AsyncThrowingStream<Data, Error> {
    let sequence = self
    return AsyncThrowingStream { continuation in
      Task {
        do {
          let decompressor = try XZDecompressor(configuration: configuration)
          let bufferSize = configuration.bufferSize.bytes
          var buffer = Data()
          buffer.reserveCapacity(bufferSize)

          for try await byte in sequence {
            buffer.append(byte)

            if buffer.count >= bufferSize {
              let decompressed = try await decompressor.decompress(buffer)
              if !decompressed.isEmpty {
                continuation.yield(decompressed)
              }
              buffer.removeAll(keepingCapacity: true)
            }
          }

          // Process any remaining bytes
          if !buffer.isEmpty {
            let decompressed = try await decompressor.decompress(buffer)
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
        } catch let error as XZError {
          continuation.finish(throwing: error)
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
}

// MARK: - AsyncSequence where Element == Data

extension AsyncSequence where Element == Data, Self: Sendable {
  /// Returns an async stream of XZ compressed data chunks.
  ///
  /// This method consumes data chunks from the async sequence and produces
  /// compressed XZ data as an async throwing stream.
  ///
  /// - Parameter configuration: The compression configuration to use.
  /// - Returns: An async throwing stream of compressed data chunks.
  public func xzCompressed(
    configuration: XZConfiguration = .default
  ) -> AsyncThrowingStream<Data, Error> {
    let sequence = self
    return AsyncThrowingStream { continuation in
      Task {
        do {
          let compressor = try XZCompressor(configuration: configuration)

          for try await chunk in sequence {
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
        } catch let error as XZError {
          continuation.finish(throwing: error)
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  /// Returns an async stream of decompressed data chunks.
  ///
  /// This method consumes XZ compressed data chunks from the async sequence
  /// and produces decompressed data as an async throwing stream.
  ///
  /// - Parameter configuration: The decompression configuration to use.
  /// - Returns: An async throwing stream of decompressed data chunks.
  public func xzDecompressed(
    configuration: XZConfiguration = .default
  ) -> AsyncThrowingStream<Data, Error> {
    let sequence = self
    return AsyncThrowingStream { continuation in
      Task {
        do {
          let decompressor = try XZDecompressor(configuration: configuration)

          for try await chunk in sequence {
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
        } catch let error as XZError {
          continuation.finish(throwing: error)
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
}
