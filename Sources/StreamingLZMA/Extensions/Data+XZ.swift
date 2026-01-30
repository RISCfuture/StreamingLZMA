import Clzma
import Foundation

extension Data {
  /// Compresses the data using XZ compression.
  ///
  /// This method produces XZ compressed data compatible with the `xz` command-line tool
  /// and `NSData.compressed(using: .lzma)`.
  ///
  /// - Parameter configuration: The compression configuration to use.
  /// - Returns: The compressed data.
  /// - Throws: ``XZError`` if compression fails.
  public func xzCompressed(configuration: XZConfiguration = .default) throws(XZError) -> Data {
    guard !isEmpty else {
      throw .emptyInput
    }

    let bufferSize = configuration.bufferSize.bytes
    var output = Data()
    var processingError: XZError?

    withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
      guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        processingError = .processingFailed
        return
      }

      var stream = lzma_stream()
      var ret = lzma_easy_encoder(
        &stream,
        configuration.preset,
        lzma_check(configuration.check.rawValue)
      )

      guard ret == LZMA_OK else {
        processingError = .streamInitializationFailed
        return
      }

      defer {
        lzma_end(&stream)
      }

      let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer {
        destinationBuffer.deallocate()
      }

      stream.next_in = sourcePointer
      stream.avail_in = count
      stream.next_out = destinationBuffer
      stream.avail_out = bufferSize

      // Process all input
      while stream.avail_in > 0 {
        ret = lzma_code(&stream, LZMA_RUN)

        switch ret {
          case LZMA_OK, LZMA_STREAM_END:
            let outputSize = bufferSize - stream.avail_out
            if outputSize > 0 {
              output.append(destinationBuffer, count: outputSize)
            }
            stream.next_out = destinationBuffer
            stream.avail_out = bufferSize
          case LZMA_MEM_ERROR:
            processingError = .memoryError
            return
          default:
            processingError = .internalError("lzma_code returned \(ret)")
            return
        }
      }

      // Finalize
      while true {
        ret = lzma_code(&stream, LZMA_FINISH)

        let outputSize = bufferSize - stream.avail_out
        if outputSize > 0 {
          output.append(destinationBuffer, count: outputSize)
        }

        if ret == LZMA_STREAM_END {
          break
        }
        if ret != LZMA_OK {
          processingError = .processingFailed
          return
        }

        stream.next_out = destinationBuffer
        stream.avail_out = bufferSize
      }
    }

    if let processingError {
      throw processingError
    }

    return output
  }

  /// Decompresses XZ compressed data.
  ///
  /// This method decompresses data created by XZ compression, including data from
  /// the `xz` command-line tool and `NSData.compressed(using: .lzma)`.
  ///
  /// - Parameter configuration: The decompression configuration to use.
  /// - Returns: The decompressed data.
  /// - Throws: ``XZError`` if decompression fails.
  public func xzDecompressed(configuration: XZConfiguration = .default) throws(XZError) -> Data {
    guard !isEmpty else {
      throw .emptyInput
    }

    let bufferSize = configuration.bufferSize.bytes
    var output = Data()
    var processingError: XZError?

    withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
      guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        processingError = .processingFailed
        return
      }

      var stream = lzma_stream()
      // Use auto decoder which handles both XZ and raw LZMA streams
      var ret = lzma_auto_decoder(&stream, UInt64.max, 0)

      guard ret == LZMA_OK else {
        processingError = .streamInitializationFailed
        return
      }

      defer {
        lzma_end(&stream)
      }

      let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer {
        destinationBuffer.deallocate()
      }

      stream.next_in = sourcePointer
      stream.avail_in = count
      stream.next_out = destinationBuffer
      stream.avail_out = bufferSize

      // Process all input
      while true {
        ret = lzma_code(&stream, LZMA_FINISH)

        let outputSize = bufferSize - stream.avail_out
        if outputSize > 0 {
          output.append(destinationBuffer, count: outputSize)
        }

        switch ret {
          case LZMA_OK:
            stream.next_out = destinationBuffer
            stream.avail_out = bufferSize
          case LZMA_STREAM_END:
            return
          case LZMA_MEM_ERROR:
            processingError = .memoryError
            return
          case LZMA_DATA_ERROR, LZMA_FORMAT_ERROR:
            processingError = .corruptedData
            return
          default:
            processingError = .internalError("lzma_code returned \(ret)")
            return
        }
      }
    }

    if let processingError { throw processingError }

    return output
  }
}
