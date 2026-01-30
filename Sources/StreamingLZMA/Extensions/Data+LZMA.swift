import Compression
import Foundation

extension Data {
  // MARK: - Raw Stream API

  /// Compresses the data using LZMA compression (raw stream, no header).
  ///
  /// This method produces raw LZMA compressed data without the .lzma file format
  /// header. For CLI-compatible output, use `lzmaFileCompressed()` instead.
  ///
  /// - Parameter configuration: The compression configuration to use.
  /// - Returns: The compressed data.
  /// - Throws: ``LZMAError`` if compression fails.
  public func lzmaCompressed(configuration: LZMAConfiguration = .default) throws(LZMAError) -> Data
  {
    guard !isEmpty else {
      throw .emptyInput
    }

    let bufferSize = configuration.bufferSize.bytes
    var output = Data()
    var processingError: LZMAError?

    withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
      guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        processingError = .processingFailed
        return
      }

      var stream = compression_stream(
        dst_ptr: UnsafeMutablePointer(bitPattern: 1)!,
        dst_size: 0,
        src_ptr: sourcePointer,
        src_size: count,
        state: nil
      )

      var status = compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_LZMA)

      guard status == COMPRESSION_STATUS_OK else {
        processingError = .streamInitializationFailed
        return
      }

      defer {
        compression_stream_destroy(&stream)
      }

      let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer {
        destinationBuffer.deallocate()
      }

      stream.src_ptr = sourcePointer
      stream.src_size = count
      stream.dst_ptr = destinationBuffer
      stream.dst_size = bufferSize

      // Process all input
      while stream.src_size > 0 {
        status = compression_stream_process(&stream, 0)

        switch status {
          case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
            let outputSize = bufferSize - stream.dst_size
            if outputSize > 0 {
              output.append(destinationBuffer, count: outputSize)
            }
            stream.dst_ptr = destinationBuffer
            stream.dst_size = bufferSize
          case COMPRESSION_STATUS_ERROR:
            processingError = .processingFailed
            return
          default:
            processingError = .internalError("Unknown compression status: \(status)")
            return
        }
      }

      // Finalize
      while true {
        status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

        let outputSize = bufferSize - stream.dst_size
        if outputSize > 0 {
          output.append(destinationBuffer, count: outputSize)
        }

        if status == COMPRESSION_STATUS_END {
          break
        }
        if status == COMPRESSION_STATUS_ERROR {
          processingError = .processingFailed
          return
        }

        stream.dst_ptr = destinationBuffer
        stream.dst_size = bufferSize
      }
    }

    if let processingError {
      throw processingError
    }

    return output
  }

  /// Decompresses LZMA compressed data (raw stream, no header).
  ///
  /// This method expects raw LZMA compressed data without the .lzma file format
  /// header. For CLI-compatible input, use `lzmaFileDecompressed()` instead.
  ///
  /// - Parameter configuration: The decompression configuration to use.
  /// - Returns: The decompressed data.
  /// - Throws: ``LZMAError`` if decompression fails.
  public func lzmaDecompressed(configuration: LZMAConfiguration = .default) throws(LZMAError)
    -> Data
  {
    guard !isEmpty else {
      throw .emptyInput
    }

    let bufferSize = configuration.bufferSize.bytes
    var output = Data()
    var processingError: LZMAError?

    withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
      guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        processingError = .processingFailed
        return
      }

      var stream = compression_stream(
        dst_ptr: UnsafeMutablePointer(bitPattern: 1)!,
        dst_size: 0,
        src_ptr: sourcePointer,
        src_size: count,
        state: nil
      )

      var status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_LZMA)

      guard status == COMPRESSION_STATUS_OK else {
        processingError = .streamInitializationFailed
        return
      }

      defer {
        compression_stream_destroy(&stream)
      }

      let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer {
        destinationBuffer.deallocate()
      }

      stream.src_ptr = sourcePointer
      stream.src_size = count
      stream.dst_ptr = destinationBuffer
      stream.dst_size = bufferSize

      // Process all input
      while true {
        status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

        let outputSize = bufferSize - stream.dst_size
        if outputSize > 0 {
          output.append(destinationBuffer, count: outputSize)
        }

        switch status {
          case COMPRESSION_STATUS_OK:
            stream.dst_ptr = destinationBuffer
            stream.dst_size = bufferSize
          case COMPRESSION_STATUS_END:
            return
          case COMPRESSION_STATUS_ERROR:
            processingError = .corruptedData
            return
          default:
            processingError = .internalError("Unknown compression status: \(status)")
            return
        }
      }
    }

    if let processingError { throw processingError }

    return output
  }

  // MARK: - CLI-Compatible File Format API

  /// Compresses the data to .lzma file format (CLI-compatible).
  ///
  /// This method produces output compatible with command-line tools like `lzma`,
  /// `xz`, and `7z`. The output includes a 13-byte header followed by the
  /// compressed data stream.
  ///
  /// - Parameter configuration: The compression configuration to use.
  /// - Returns: The compressed data with .lzma file format header.
  /// - Throws: ``LZMAError`` if compression fails.
  public func lzmaFileCompressed(configuration: LZMAConfiguration = .default) throws(LZMAError)
    -> Data
  {
    let header = LZMAFileHeader(uncompressedSize: UInt64(count))
    let compressedData = try lzmaCompressed(configuration: configuration)
    return header.encoded() + compressedData
  }

  /// Decompresses .lzma file format data (CLI-compatible).
  ///
  /// This method expects input created by command-line tools like `lzma`, `xz`,
  /// or `7z`. It automatically strips the 13-byte header before decompression.
  ///
  /// - Parameter configuration: The decompression configuration to use.
  /// - Returns: The decompressed data.
  /// - Throws: ``LZMAError`` if decompression fails or the header is invalid.
  public func lzmaFileDecompressed(configuration: LZMAConfiguration = .default) throws(LZMAError)
    -> Data
  {
    guard count > LZMAFileFormat.headerSize else {
      throw .corruptedData
    }

    // Parse and validate header (we don't use the values, but we verify format)
    _ = try LZMAFileHeader(from: self)

    // Strip header and decompress
    let compressedData = self.dropFirst(LZMAFileFormat.headerSize)
    return try Data(compressedData).lzmaDecompressed(configuration: configuration)
  }
}
