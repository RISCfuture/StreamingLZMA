import Compression
import Foundation

extension FileHandle {
  // MARK: - Raw Stream API

  /// Compresses data from this file handle to a destination file handle (raw stream).
  ///
  /// This method streams data in chunks, never loading the entire file into memory.
  /// It produces raw LZMA compressed data without the .lzma file format header.
  ///
  /// - Parameters:
  ///   - destination: The file handle to write compressed data to.
  ///   - configuration: The compression configuration to use.
  ///   - progress: Optional callback reporting bytes read from source.
  /// - Throws: ``LZMAError`` if compression fails.
  public func lzmaCompress(
    to destination: FileHandle,
    configuration: LZMAConfiguration = .default,
    progress: ((Int64) -> Void)? = nil
  ) throws(LZMAError) {
    let bufferSize = configuration.bufferSize.bytes

    // Initialize compression stream
    var stream = compression_stream(
      dst_ptr: UnsafeMutablePointer(bitPattern: 1)!,
      dst_size: 0,
      src_ptr: UnsafePointer(bitPattern: 1)!,
      src_size: 0,
      state: nil
    )

    var status = compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_LZMA)
    guard status == COMPRESSION_STATUS_OK else {
      throw .streamInitializationFailed
    }

    defer {
      compression_stream_destroy(&stream)
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
        chunk = try _readData(ofLength: bufferSize)
      } catch {
        throw LZMAError.internalError("Failed to read from source: \(error)")
      }

      if chunk.isEmpty {
        break
      }

      totalBytesRead += Int64(chunk.count)
      progress?(totalBytesRead)

      // Copy to our buffer
      chunk.copyBytes(to: sourceBuffer, count: chunk.count)

      stream.src_ptr = UnsafePointer(sourceBuffer)
      stream.src_size = chunk.count
      stream.dst_ptr = destinationBuffer
      stream.dst_size = bufferSize

      while stream.src_size > 0 {
        status = compression_stream_process(&stream, 0)

        let outputSize = bufferSize - stream.dst_size
        if outputSize > 0 {
          let outputData = Data(bytes: destinationBuffer, count: outputSize)
          do {
            try destination.write(contentsOf: outputData)
          } catch {
            throw LZMAError.internalError("Failed to write: \(error)")
          }
        }

        if status == COMPRESSION_STATUS_ERROR {
          throw LZMAError.processingFailed
        }

        stream.dst_ptr = destinationBuffer
        stream.dst_size = bufferSize
      }
    }

    // Finalize
    stream.src_size = 0
    stream.dst_ptr = destinationBuffer
    stream.dst_size = bufferSize

    while true {
      status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

      let outputSize = bufferSize - stream.dst_size
      if outputSize > 0 {
        let outputData = Data(bytes: destinationBuffer, count: outputSize)
        do {
          try destination.write(contentsOf: outputData)
        } catch {
          throw LZMAError.internalError("Failed to write final data: \(error)")
        }
      }

      if status == COMPRESSION_STATUS_END {
        break
      }
      if status == COMPRESSION_STATUS_ERROR {
        throw LZMAError.processingFailed
      }

      stream.dst_ptr = destinationBuffer
      stream.dst_size = bufferSize
    }
  }

  /// Decompresses data from this file handle to a destination file handle (raw stream).
  ///
  /// This method streams data in chunks, never loading the entire file into memory.
  /// It expects raw LZMA compressed data without the .lzma file format header.
  ///
  /// - Parameters:
  ///   - destination: The file handle to write decompressed data to.
  ///   - configuration: The decompression configuration to use.
  ///   - progress: Optional callback reporting bytes read from source.
  /// - Throws: ``LZMAError`` if decompression fails.
  public func lzmaDecompress(
    to destination: FileHandle,
    configuration: LZMAConfiguration = .default,
    progress: ((Int64) -> Void)? = nil
  ) throws(LZMAError) {
    let bufferSize = configuration.bufferSize.bytes

    // Initialize decompression stream
    var stream = compression_stream(
      dst_ptr: UnsafeMutablePointer(bitPattern: 1)!,
      dst_size: 0,
      src_ptr: UnsafePointer(bitPattern: 1)!,
      src_size: 0,
      state: nil
    )

    var status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_LZMA)
    guard status == COMPRESSION_STATUS_OK else {
      throw .streamInitializationFailed
    }

    defer {
      compression_stream_destroy(&stream)
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
        chunk = try _readData(ofLength: bufferSize)
      } catch {
        throw LZMAError.internalError("Failed to read from source: \(error)")
      }

      if chunk.isEmpty {
        break
      }

      totalBytesRead += Int64(chunk.count)
      progress?(totalBytesRead)

      // Copy to our buffer
      chunk.copyBytes(to: sourceBuffer, count: chunk.count)

      stream.src_ptr = UnsafePointer(sourceBuffer)
      stream.src_size = chunk.count
      stream.dst_ptr = destinationBuffer
      stream.dst_size = bufferSize

      while stream.src_size > 0 || status == COMPRESSION_STATUS_OK {
        status = compression_stream_process(&stream, 0)

        let outputSize = bufferSize - stream.dst_size
        if outputSize > 0 {
          let outputData = Data(bytes: destinationBuffer, count: outputSize)
          do {
            try destination.write(contentsOf: outputData)
          } catch {
            throw LZMAError.internalError("Failed to write: \(error)")
          }
        }

        if status == COMPRESSION_STATUS_ERROR {
          throw LZMAError.corruptedData
        }

        if status == COMPRESSION_STATUS_END {
          return
        }

        stream.dst_ptr = destinationBuffer
        stream.dst_size = bufferSize

        if stream.src_size == 0 {
          break
        }
      }
    }

    // Finalize
    stream.src_size = 0
    stream.dst_ptr = destinationBuffer
    stream.dst_size = bufferSize

    while true {
      status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

      let outputSize = bufferSize - stream.dst_size
      if outputSize > 0 {
        let outputData = Data(bytes: destinationBuffer, count: outputSize)
        do {
          try destination.write(contentsOf: outputData)
        } catch {
          throw LZMAError.internalError("Failed to write final data: \(error)")
        }
      }

      if status == COMPRESSION_STATUS_END {
        break
      }
      if status == COMPRESSION_STATUS_ERROR {
        throw LZMAError.corruptedData
      }

      stream.dst_ptr = destinationBuffer
      stream.dst_size = bufferSize
    }
  }

  // MARK: - CLI-Compatible File Format API

  /// Compresses data from this file handle to .lzma file format (CLI-compatible).
  ///
  /// This method streams data in chunks, never loading the entire file into memory.
  /// It produces output compatible with command-line tools like `lzma`, `xz`, and `7z`.
  ///
  /// - Parameters:
  ///   - destination: The file handle to write compressed data to.
  ///   - configuration: The compression configuration to use.
  ///   - progress: Optional callback reporting bytes read from source.
  /// - Throws: ``LZMAError`` if compression fails.
  public func lzmaFileCompress(
    to destination: FileHandle,
    configuration: LZMAConfiguration = .default,
    progress: ((Int64) -> Void)? = nil
  ) throws(LZMAError) {
    // For streaming, we use unknown size in the header since we don't know the total size upfront
    let header = LZMAFileHeader.default

    // Write header
    do {
      try destination.write(contentsOf: header.encoded())
    } catch {
      throw LZMAError.internalError("Failed to write header: \(error)")
    }

    // Compress the rest
    try lzmaCompress(to: destination, configuration: configuration, progress: progress)
  }

  /// Decompresses .lzma file format data from this file handle (CLI-compatible).
  ///
  /// This method streams data in chunks, never loading the entire file into memory.
  /// It expects input created by command-line tools like `lzma`, `xz`, or `7z`.
  ///
  /// - Parameters:
  ///   - destination: The file handle to write decompressed data to.
  ///   - configuration: The decompression configuration to use.
  ///   - progress: Optional callback reporting bytes read from source.
  /// - Throws: ``LZMAError`` if decompression fails or the header is invalid.
  public func lzmaFileDecompress(
    to destination: FileHandle,
    configuration: LZMAConfiguration = .default,
    progress: ((Int64) -> Void)? = nil
  ) throws(LZMAError) {
    // Read and parse header
    let headerData: Data
    do {
      headerData = try _readData(ofLength: LZMAFileFormat.headerSize)
    } catch {
      throw LZMAError.internalError("Failed to read header: \(error)")
    }

    guard headerData.count == LZMAFileFormat.headerSize else {
      throw .corruptedData
    }

    // Validate header (we don't use the values, but we verify format)
    _ = try LZMAFileHeader(from: headerData)

    // Decompress the rest
    try lzmaDecompress(to: destination, configuration: configuration, progress: progress)
  }

  // MARK: - Internal

  /// Reads up to the specified number of bytes.
  /// - Parameter length: Maximum number of bytes to read.
  /// - Returns: The data read, or empty data if at end of file.
  private func _readData(ofLength length: Int) throws -> Data {
    if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
      return try read(upToCount: length) ?? Data()
    } else {
      return readData(ofLength: length)
    }
  }
}
