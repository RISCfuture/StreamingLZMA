import Clzma
import Foundation

extension FileHandle {
  /// Compresses data from this file handle to a destination file handle using XZ compression.
  ///
  /// This method streams data in chunks, never loading the entire file into memory.
  /// It produces XZ compressed data compatible with the `xz` command-line tool.
  ///
  /// - Parameters:
  ///   - destination: The file handle to write compressed data to.
  ///   - configuration: The compression configuration to use.
  ///   - progress: Optional callback reporting bytes read from source.
  /// - Throws: ``XZError`` if compression fails.
  public func xzCompress(
    to destination: FileHandle,
    configuration: XZConfiguration = .default,
    progress: ((Int64) -> Void)? = nil
  ) throws(XZError) {
    let bufferSize = configuration.bufferSize.bytes

    // Initialize compression stream
    var stream = lzma_stream()
    var ret = lzma_easy_encoder(
      &stream,
      configuration.preset,
      lzma_check(configuration.check.rawValue)
    )

    guard ret == LZMA_OK else {
      throw .streamInitializationFailed
    }

    defer {
      lzma_end(&stream)
    }

    let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { destinationBuffer.deallocate() }

    let sourceBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { sourceBuffer.deallocate() }

    var totalBytesRead: Int64 = 0

    // Process input in chunks
    while true {
      let chunk: Data
      do {
        chunk = try _xzReadData(ofLength: bufferSize)
      } catch {
        throw XZError.internalError("Failed to read from source: \(error)")
      }

      if chunk.isEmpty {
        break
      }

      totalBytesRead += Int64(chunk.count)
      progress?(totalBytesRead)

      // Copy to our buffer
      chunk.copyBytes(to: sourceBuffer, count: chunk.count)

      stream.next_in = UnsafePointer(sourceBuffer)
      stream.avail_in = chunk.count
      stream.next_out = destinationBuffer
      stream.avail_out = bufferSize

      while stream.avail_in > 0 {
        ret = lzma_code(&stream, LZMA_RUN)

        let outputSize = bufferSize - stream.avail_out
        if outputSize > 0 {
          let outputData = Data(bytes: destinationBuffer, count: outputSize)
          do {
            try destination.write(contentsOf: outputData)
          } catch {
            throw XZError.internalError("Failed to write: \(error)")
          }
        }

        if ret == LZMA_MEM_ERROR {
          throw XZError.memoryError
        }
        if ret != LZMA_OK && ret != LZMA_STREAM_END {
          throw XZError.processingFailed
        }

        stream.next_out = destinationBuffer
        stream.avail_out = bufferSize
      }
    }

    // Finalize
    stream.avail_in = 0
    stream.next_out = destinationBuffer
    stream.avail_out = bufferSize

    while true {
      ret = lzma_code(&stream, LZMA_FINISH)

      let outputSize = bufferSize - stream.avail_out
      if outputSize > 0 {
        let outputData = Data(bytes: destinationBuffer, count: outputSize)
        do {
          try destination.write(contentsOf: outputData)
        } catch {
          throw XZError.internalError("Failed to write final data: \(error)")
        }
      }

      if ret == LZMA_STREAM_END {
        break
      }
      if ret != LZMA_OK {
        throw XZError.processingFailed
      }

      stream.next_out = destinationBuffer
      stream.avail_out = bufferSize
    }
  }

  /// Decompresses XZ data from this file handle to a destination file handle.
  ///
  /// This method streams data in chunks, never loading the entire file into memory.
  /// It handles XZ compressed data from the `xz` command-line tool or `NSData.compressed(using: .lzma)`.
  ///
  /// - Parameters:
  ///   - destination: The file handle to write decompressed data to.
  ///   - configuration: The decompression configuration to use.
  ///   - progress: Optional callback reporting bytes read from source.
  /// - Throws: ``XZError`` if decompression fails.
  public func xzDecompress(
    to destination: FileHandle,
    configuration: XZConfiguration = .default,
    progress: ((Int64) -> Void)? = nil
  ) throws(XZError) {
    let bufferSize = configuration.bufferSize.bytes

    // Initialize decompression stream
    var stream = lzma_stream()
    var ret = lzma_auto_decoder(&stream, UInt64.max, 0)

    guard ret == LZMA_OK else {
      throw .streamInitializationFailed
    }

    defer {
      lzma_end(&stream)
    }

    let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { destinationBuffer.deallocate() }

    let sourceBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { sourceBuffer.deallocate() }

    var totalBytesRead: Int64 = 0

    // Process input in chunks
    while true {
      let chunk: Data
      do {
        chunk = try _xzReadData(ofLength: bufferSize)
      } catch {
        throw XZError.internalError("Failed to read from source: \(error)")
      }

      if chunk.isEmpty {
        break
      }

      totalBytesRead += Int64(chunk.count)
      progress?(totalBytesRead)

      // Copy to our buffer
      chunk.copyBytes(to: sourceBuffer, count: chunk.count)

      stream.next_in = UnsafePointer(sourceBuffer)
      stream.avail_in = chunk.count
      stream.next_out = destinationBuffer
      stream.avail_out = bufferSize

      while stream.avail_in > 0 || ret == LZMA_OK {
        ret = lzma_code(&stream, LZMA_RUN)

        let outputSize = bufferSize - stream.avail_out
        if outputSize > 0 {
          let outputData = Data(bytes: destinationBuffer, count: outputSize)
          do {
            try destination.write(contentsOf: outputData)
          } catch {
            throw XZError.internalError("Failed to write: \(error)")
          }
        }

        if ret == LZMA_MEM_ERROR {
          throw XZError.memoryError
        }
        if ret == LZMA_DATA_ERROR || ret == LZMA_FORMAT_ERROR {
          throw XZError.corruptedData
        }

        if ret == LZMA_STREAM_END {
          return
        }

        stream.next_out = destinationBuffer
        stream.avail_out = bufferSize

        if stream.avail_in == 0 {
          break
        }
      }
    }

    // Finalize
    stream.avail_in = 0
    stream.next_out = destinationBuffer
    stream.avail_out = bufferSize

    while true {
      ret = lzma_code(&stream, LZMA_FINISH)

      let outputSize = bufferSize - stream.avail_out
      if outputSize > 0 {
        let outputData = Data(bytes: destinationBuffer, count: outputSize)
        do {
          try destination.write(contentsOf: outputData)
        } catch {
          throw XZError.internalError("Failed to write final data: \(error)")
        }
      }

      if ret == LZMA_STREAM_END {
        break
      }
      if ret == LZMA_DATA_ERROR || ret == LZMA_FORMAT_ERROR {
        throw XZError.corruptedData
      }
      if ret != LZMA_OK {
        throw XZError.processingFailed
      }

      stream.next_out = destinationBuffer
      stream.avail_out = bufferSize
    }
  }

  // MARK: - Internal

  /// Reads up to the specified number of bytes.
  /// - Parameter length: Maximum number of bytes to read.
  /// - Returns: The data read, or empty data if at end of file.
  private func _xzReadData(ofLength length: Int) throws -> Data {
    if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
      return try read(upToCount: length) ?? Data()
    } else {
      return readData(ofLength: length)
    }
  }
}
