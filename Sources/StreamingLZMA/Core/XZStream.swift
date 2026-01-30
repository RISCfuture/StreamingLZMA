import Clzma
import Foundation

/// Internal wrapper around liblzma's `lzma_stream` C API.
///
/// This class manages the lifecycle of an XZ compression stream, including initialization,
/// processing, and cleanup. It is not thread-safe and relies on external synchronization
/// (provided by actor isolation in the public API).
final class XZStream {
  // MARK: - Instance Properties

  private var stream: lzma_stream
  private let direction: Direction
  private let bufferSize: Int
  private var destinationBuffer: UnsafeMutablePointer<UInt8>
  private var isFinalized: Bool = false
  private let preset: UInt32
  private let check: lzma_check

  // MARK: - Initializers

  /// Creates a new XZ stream.
  /// - Parameters:
  ///   - direction: Whether to compress or decompress.
  ///   - bufferSize: The size of the output buffer.
  ///   - preset: Compression preset (0-9) for compression direction.
  ///   - check: Integrity check type for compression direction.
  /// - Throws: ``XZError/streamInitializationFailed`` if the stream cannot be initialized.
  init(
    direction: Direction,
    bufferSize: Int,
    preset: UInt32 = 6,
    check: XZConfiguration.Check = .crc64
  ) throws(XZError) {
    self.direction = direction
    self.bufferSize = bufferSize
    self.preset = preset
    self.check = lzma_check(check.rawValue)

    // Allocate destination buffer
    self.destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

    // Initialize the stream with zeroed memory
    self.stream = lzma_stream()

    let ret: lzma_ret
    switch direction {
      case .compress:
        ret = lzma_easy_encoder(&stream, preset, self.check)
      case .decompress:
        // Use auto decoder which handles both XZ and raw LZMA streams
        ret = lzma_auto_decoder(&stream, UInt64.max, 0)
    }

    guard ret == LZMA_OK else {
      destinationBuffer.deallocate()
      throw Self.mapError(ret)
    }
  }

  // MARK: - Type Methods

  /// Maps liblzma return codes to XZError.
  private static func mapError(_ ret: lzma_ret) -> XZError {
    switch ret {
      case LZMA_MEM_ERROR:
        return .memoryError
      case LZMA_OPTIONS_ERROR:
        return .streamInitializationFailed
      case LZMA_UNSUPPORTED_CHECK:
        return .unsupportedCheck
      case LZMA_DATA_ERROR, LZMA_FORMAT_ERROR:
        return .corruptedData
      default:
        return .streamInitializationFailed
    }
  }

  // MARK: - Instance Methods

  /// Processes input data and returns compressed/decompressed output.
  /// - Parameter data: The input data to process.
  /// - Returns: The processed output data.
  /// - Throws: `XZError` if processing fails.
  func process(_ data: Data) throws(XZError) -> Data {
    guard !isFinalized else {
      throw .streamAlreadyFinalized
    }

    var output = Data()

    if data.isEmpty {
      return output
    }

    var processingError: XZError?

    data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
      guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        processingError = .processingFailed
        return
      }

      stream.next_in = sourcePointer
      stream.avail_in = data.count

      while stream.avail_in > 0 {
        // Reset destination buffer
        stream.next_out = destinationBuffer
        stream.avail_out = bufferSize

        let ret = lzma_code(&stream, LZMA_RUN)

        switch ret {
          case LZMA_OK:
            // Append any output produced
            let outputSize = bufferSize - stream.avail_out
            if outputSize > 0 {
              output.append(destinationBuffer, count: outputSize)
            }
          case LZMA_STREAM_END:
            // Stream ended (shouldn't happen during normal processing without FINISH)
            let outputSize = bufferSize - stream.avail_out
            if outputSize > 0 {
              output.append(destinationBuffer, count: outputSize)
            }
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

  /// Finalizes the stream and returns any remaining output.
  /// - Returns: Any remaining processed data.
  /// - Throws: `XZError` if finalization fails.
  func finalize() throws(XZError) -> Data {
    guard !isFinalized else {
      throw .streamAlreadyFinalized
    }

    isFinalized = true
    var output = Data()

    // Set input to empty
    stream.next_in = nil
    stream.avail_in = 0

    while true {
      // Reset destination buffer
      stream.next_out = destinationBuffer
      stream.avail_out = bufferSize

      let ret = lzma_code(&stream, LZMA_FINISH)

      // Append any output produced
      let outputSize = bufferSize - stream.avail_out
      if outputSize > 0 {
        output.append(destinationBuffer, count: outputSize)
      }

      switch ret {
        case LZMA_OK:
          // Continue processing
          continue
        case LZMA_STREAM_END:
          // Successfully finalized
          return output
        case LZMA_MEM_ERROR:
          throw XZError.memoryError
        case LZMA_DATA_ERROR, LZMA_FORMAT_ERROR:
          throw XZError.corruptedData
        default:
          throw XZError.internalError("lzma_code finalize returned \(ret)")
      }
    }
  }

  /// Resets the stream for reuse.
  /// - Throws: ``XZError/streamInitializationFailed`` if reinitialization fails.
  func reset() throws(XZError) {
    // End the old stream
    lzma_end(&stream)

    // Reinitialize
    self.stream = lzma_stream()

    let ret: lzma_ret
    switch direction {
      case .compress:
        ret = lzma_easy_encoder(&stream, preset, check)
      case .decompress:
        ret = lzma_auto_decoder(&stream, UInt64.max, 0)
    }

    guard ret == LZMA_OK else {
      throw Self.mapError(ret)
    }

    isFinalized = false
  }

  // MARK: - Deinitializer

  deinit {
    lzma_end(&stream)
    destinationBuffer.deallocate()
  }

  // MARK: - Nested Types

  /// The direction of the stream (compression or decompression).
  enum Direction {
    case compress
    case decompress
  }
}
