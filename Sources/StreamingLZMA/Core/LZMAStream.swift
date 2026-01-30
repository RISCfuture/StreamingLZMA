import Compression
import Foundation

/// Internal wrapper around Apple's `compression_stream` C API.
///
/// This class manages the lifecycle of a compression stream, including initialization,
/// processing, and cleanup. It is not thread-safe and relies on external synchronization
/// (provided by actor isolation in the public API).
final class LZMAStream {
  // MARK: - Instance Properties

  private var stream: compression_stream
  private let direction: Direction
  private let bufferSize: Int
  private var destinationBuffer: UnsafeMutablePointer<UInt8>
  private var isFinalized: Bool = false

  // MARK: - Initializers

  /// Creates a new LZMA stream.
  /// - Parameters:
  ///   - direction: Whether to compress or decompress.
  ///   - bufferSize: The size of the output buffer.
  /// - Throws: ``LZMAError/streamInitializationFailed`` if the stream cannot be initialized.
  init(direction: Direction, bufferSize: Int) throws(LZMAError) {
    self.direction = direction
    self.bufferSize = bufferSize

    // Allocate destination buffer
    self.destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

    // Initialize the stream with zeroed memory
    self.stream = compression_stream(
      dst_ptr: destinationBuffer,
      dst_size: bufferSize,
      src_ptr: UnsafePointer(bitPattern: 1)!,  // Non-null placeholder, will be set during process
      src_size: 0,
      state: nil
    )

    let status = compression_stream_init(
      &stream,
      direction.operation,
      COMPRESSION_LZMA
    )

    guard status == COMPRESSION_STATUS_OK else {
      destinationBuffer.deallocate()
      throw .streamInitializationFailed
    }

    // Set up the destination buffer after init
    stream.dst_ptr = destinationBuffer
    stream.dst_size = bufferSize
  }

  // MARK: - Instance Methods

  /// Processes input data and returns compressed/decompressed output.
  /// - Parameter data: The input data to process.
  /// - Returns: The processed output data.
  /// - Throws: `LZMAError` if processing fails.
  func process(_ data: Data) throws(LZMAError) -> Data {
    guard !isFinalized else {
      throw .streamAlreadyFinalized
    }

    var output = Data()

    if data.isEmpty {
      return output
    }

    var processingError: LZMAError?

    data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
      guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        processingError = .processingFailed
        return
      }

      stream.src_ptr = sourcePointer
      stream.src_size = data.count

      while stream.src_size > 0 {
        // Reset destination buffer
        stream.dst_ptr = destinationBuffer
        stream.dst_size = bufferSize

        let status = compression_stream_process(&stream, 0)

        switch status {
          case COMPRESSION_STATUS_OK:
            // Append any output produced
            let outputSize = bufferSize - stream.dst_size
            if outputSize > 0 {
              output.append(destinationBuffer, count: outputSize)
            }
          case COMPRESSION_STATUS_END:
            // Stream ended (shouldn't happen during normal processing)
            let outputSize = bufferSize - stream.dst_size
            if outputSize > 0 {
              output.append(destinationBuffer, count: outputSize)
            }
            return
          case COMPRESSION_STATUS_ERROR:
            processingError = .processingFailed
            return
          default:
            processingError = .internalError("Unknown compression status: \(status)")
            return
        }
      }
    }

    if let processingError {
      throw processingError
    }

    return output
  }

  /// Finalizes the stream and returns any remaining output.
  /// - Returns: Any remaining processed data.
  /// - Throws: `LZMAError` if finalization fails.
  func finalize() throws(LZMAError) -> Data {
    guard !isFinalized else {
      throw .streamAlreadyFinalized
    }

    isFinalized = true
    var output = Data()

    // Set source to empty - use a valid pointer with zero size
    let emptyByte: UInt8 = 0
    withUnsafePointer(to: emptyByte) { ptr in
      stream.src_ptr = ptr
    }
    stream.src_size = 0

    while true {
      // Reset destination buffer
      stream.dst_ptr = destinationBuffer
      stream.dst_size = bufferSize

      let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

      // Append any output produced
      let outputSize = bufferSize - stream.dst_size
      if outputSize > 0 {
        output.append(destinationBuffer, count: outputSize)
      }

      switch status {
        case COMPRESSION_STATUS_OK:
          // Continue processing
          continue
        case COMPRESSION_STATUS_END:
          // Successfully finalized
          return output
        case COMPRESSION_STATUS_ERROR:
          throw LZMAError.corruptedData
        default:
          throw LZMAError.internalError("Unknown compression status: \(status)")
      }
    }
  }

  /// Resets the stream for reuse.
  /// - Throws: ``LZMAError/streamInitializationFailed`` if reinitialization fails.
  func reset() throws(LZMAError) {
    // Destroy the old stream
    compression_stream_destroy(&stream)

    // Reinitialize
    self.stream = compression_stream(
      dst_ptr: destinationBuffer,
      dst_size: bufferSize,
      src_ptr: UnsafePointer(bitPattern: 1)!,
      src_size: 0,
      state: nil
    )

    let status = compression_stream_init(
      &stream,
      direction.operation,
      COMPRESSION_LZMA
    )

    guard status == COMPRESSION_STATUS_OK else {
      throw .streamInitializationFailed
    }

    // Reset state
    stream.dst_ptr = destinationBuffer
    stream.dst_size = bufferSize
    isFinalized = false
  }

  // MARK: - Deinitializer

  deinit {
    compression_stream_destroy(&stream)
    destinationBuffer.deallocate()
  }

  // MARK: - Nested Types

  /// The direction of the stream (compression or decompression).
  enum Direction {
    case compress
    case decompress

    var operation: compression_stream_operation {
      switch self {
        case .compress:
          return COMPRESSION_STREAM_ENCODE
        case .decompress:
          return COMPRESSION_STREAM_DECODE
      }
    }
  }
}
