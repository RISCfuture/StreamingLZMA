import ArgumentParser
import Foundation
import StreamingLZMAXZ

@main
struct XZTool: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "xz-tool",
    abstract: "XZ compression and decompression tool",
    subcommands: [Compress.self, Decompress.self]
  )
}

struct Compress: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Compress a file using XZ format"
  )

  @Argument(help: "Input file path (use \"-\" for stdin)")
  var input: String

  @Option(name: .shortAndLong, help: "Output file path")
  var output: String?

  @Option(
    name: .long,
    help: "Buffer size: small, medium, large, xlarge",
    transform: BufferSize.parse
  )
  var bufferSize: BufferSize = .medium

  @Option(name: .shortAndLong, help: "Compression preset 0\u{2013}9 (default: 6)")
  var preset: UInt32 = 6

  @Option(name: .shortAndLong, help: "Integrity check: none, crc32, crc64, sha256 (default: crc64)")
  var check: CheckType = .crc64

  @Flag(name: .shortAndLong, help: "Show progress")
  var verbose: Bool = false

  func run() throws {
    let config = XZConfiguration(
      bufferSize: bufferSize.xzBufferSize,
      preset: preset,
      check: check.xzCheck
    )

    if input == "-" {
      try compressStdin(config: config)
    } else {
      let outputPath = output ?? input + ".xz"
      try compressFile(
        input: input,
        output: outputPath,
        config: config,
        verbose: verbose
      )
    }
  }
}

struct Decompress: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Decompress an XZ file"
  )

  @Argument(help: "Input file path (use \"-\" for stdin)")
  var input: String

  @Option(name: .shortAndLong, help: "Output file path")
  var output: String?

  @Option(
    name: .long,
    help: "Buffer size: small, medium, large, xlarge",
    transform: BufferSize.parse
  )
  var bufferSize: BufferSize = .medium

  @Flag(name: .shortAndLong, help: "Show progress")
  var verbose: Bool = false

  func run() throws {
    let config = XZConfiguration(bufferSize: bufferSize.xzBufferSize)

    if input == "-" {
      try decompressStdin(config: config)
    } else {
      let outputPath = output ?? defaultDecompressOutput(input)
      try decompressFile(
        input: input,
        output: outputPath,
        config: config,
        verbose: verbose
      )
    }
  }
}

// MARK: - Buffer Size

enum BufferSize: String, CaseIterable {
  case small, medium, large, xlarge

  var xzBufferSize: XZConfiguration.BufferSize {
    switch self {
      case .small: return .small
      case .medium: return .medium
      case .large: return .large
      case .xlarge: return .extraLarge
    }
  }

  static func parse(_ str: String) throws -> Self {
    guard let size = Self(rawValue: str.lowercased()) else {
      throw ValidationError(
        "Invalid buffer size: \u{201c}\(str)\u{201d}. Use: small, medium, large, or xlarge"
      )
    }
    return size
  }
}

// MARK: - Check Type

enum CheckType: String, CaseIterable, ExpressibleByArgument {
  case none, crc32, crc64, sha256

  var xzCheck: XZConfiguration.Check {
    switch self {
      case .none: return .none
      case .crc32: return .crc32
      case .crc64: return .crc64
      case .sha256: return .sha256
    }
  }
}

// MARK: - Helpers

func defaultDecompressOutput(_ input: String) -> String {
  if input.hasSuffix(".xz") {
    return String(input.dropLast(3))
  }
  return input + ".decompressed"
}

func compressFile(input: String, output: String, config: XZConfiguration, verbose: Bool) throws {
  let inputURL = URL(fileURLWithPath: input),
    outputURL = URL(fileURLWithPath: output)

  let srcHandle = try FileHandle(forReadingFrom: inputURL)
  defer { try? srcHandle.close() }

  FileManager.default.createFile(atPath: output, contents: nil)
  let dstHandle = try FileHandle(forWritingTo: outputURL)
  defer { try? dstHandle.close() }

  let progress: ((Int64) -> Void)? =
    verbose
    ? {
      let formatter = ByteCountFormatter()
      formatter.countStyle = .file
      return { bytes in
        FileHandle.standardError.write(
          Data("Processed: \(formatter.string(fromByteCount: bytes))\r".utf8)
        )
      }
    }() : nil

  try srcHandle.xzCompress(to: dstHandle, configuration: config, progress: progress)

  if verbose {
    FileHandle.standardError.write(Data("\n".utf8))
  }
}

func decompressFile(input: String, output: String, config: XZConfiguration, verbose: Bool) throws {
  let inputURL = URL(fileURLWithPath: input),
    outputURL = URL(fileURLWithPath: output)

  let srcHandle = try FileHandle(forReadingFrom: inputURL)
  defer { try? srcHandle.close() }

  FileManager.default.createFile(atPath: output, contents: nil)
  let dstHandle = try FileHandle(forWritingTo: outputURL)
  defer { try? dstHandle.close() }

  let progress: ((Int64) -> Void)? =
    verbose
    ? {
      let formatter = ByteCountFormatter()
      formatter.countStyle = .file
      return { bytes in
        FileHandle.standardError.write(
          Data("Processed: \(formatter.string(fromByteCount: bytes))\r".utf8)
        )
      }
    }() : nil

  try srcHandle.xzDecompress(to: dstHandle, configuration: config, progress: progress)

  if verbose {
    FileHandle.standardError.write(Data("\n".utf8))
  }
}

func compressStdin(config: XZConfiguration) throws {
  let data = FileHandle.standardInput.readDataToEndOfFile()
  guard !data.isEmpty else { return }
  let compressed = try data.xzCompressed(configuration: config)
  FileHandle.standardOutput.write(compressed)
}

func decompressStdin(config: XZConfiguration) throws {
  let data = FileHandle.standardInput.readDataToEndOfFile()
  guard !data.isEmpty else { return }
  let decompressed = try data.xzDecompressed(configuration: config)
  FileHandle.standardOutput.write(decompressed)
}
