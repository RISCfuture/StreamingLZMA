import Clzma
import Foundation

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#endif

/// POSIX `write`, qualified per-platform to disambiguate from `FileHandle.write`.
@inline(__always)
private func posixWrite(_ fd: Int32, _ buffer: UnsafeRawPointer, _ count: Int) -> Int {
  #if canImport(Darwin)
    Darwin.write(fd, buffer, count)
  #elseif canImport(Glibc)
    Glibc.write(fd, buffer, count)
  #elseif canImport(Musl)
    Musl.write(fd, buffer, count)
  #endif
}

/// POSIX `read`, qualified per-platform to disambiguate from `FileHandle.read`.
@inline(__always)
private func posixRead(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int {
  #if canImport(Darwin)
    Darwin.read(fd, buffer, count)
  #elseif canImport(Glibc)
    Glibc.read(fd, buffer, count)
  #elseif canImport(Musl)
    Musl.read(fd, buffer, count)
  #endif
}

extension FileHandle {
  // MARK: - Type Methods

  /// Writes all bytes from a buffer to a file descriptor, retrying on partial writes.
  ///
  /// Uses the POSIX `write` instead of `FileHandle.write(contentsOf:)` to avoid creating
  /// autoreleased `NSData` objects that accumulate in tight streaming loops.
  private static func _xzWriteAll(
    _ fd: Int32,
    _ buffer: UnsafePointer<UInt8>,
    _ count: Int
  ) throws(XZError) {
    var totalWritten = 0
    while totalWritten < count {
      let n = posixWrite(fd, buffer + totalWritten, count - totalWritten)
      guard n > 0 else {
        throw XZError.ioFailure(operation: "write", code: errno)
      }
      totalWritten += n
    }
  }

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
    let srcFD = self.fileDescriptor,
      dstFD = destination.fileDescriptor

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
      let bytesRead = posixRead(srcFD, sourceBuffer, bufferSize)
      guard bytesRead >= 0 else {
        throw XZError.ioFailure(operation: "read from source", code: errno)
      }
      if bytesRead == 0 { break }

      totalBytesRead += Int64(bytesRead)
      progress?(totalBytesRead)

      stream.next_in = UnsafePointer(sourceBuffer)
      stream.avail_in = bytesRead
      stream.next_out = destinationBuffer
      stream.avail_out = bufferSize

      while stream.avail_in > 0 {
        ret = lzma_code(&stream, LZMA_RUN)

        let outputSize = bufferSize - stream.avail_out
        if outputSize > 0 {
          try Self._xzWriteAll(dstFD, destinationBuffer, outputSize)
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
        try Self._xzWriteAll(dstFD, destinationBuffer, outputSize)
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
    let srcFD = self.fileDescriptor,
      dstFD = destination.fileDescriptor

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
      let bytesRead = posixRead(srcFD, sourceBuffer, bufferSize)
      guard bytesRead >= 0 else {
        throw XZError.ioFailure(operation: "read from source", code: errno)
      }
      if bytesRead == 0 { break }

      totalBytesRead += Int64(bytesRead)
      progress?(totalBytesRead)

      stream.next_in = UnsafePointer(sourceBuffer)
      stream.avail_in = bytesRead
      stream.next_out = destinationBuffer
      stream.avail_out = bufferSize

      while stream.avail_in > 0 || ret == LZMA_OK {
        ret = lzma_code(&stream, LZMA_RUN)

        let outputSize = bufferSize - stream.avail_out
        if outputSize > 0 {
          try Self._xzWriteAll(dstFD, destinationBuffer, outputSize)
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
        try Self._xzWriteAll(dstFD, destinationBuffer, outputSize)
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
}
