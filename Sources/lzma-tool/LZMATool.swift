import ArgumentParser
import Foundation
import StreamingLZMA

@main
struct LZMATool: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "lzma-tool",
    abstract: "LZMA compression and decompression tool",
    subcommands: [Compress.self, Decompress.self]
  )
}

struct Compress: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Compress a file using LZMA"
  )

  @Argument(help: "Input file path (use “-” for stdin)")
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
    if input == "-" {
      try compressStdin(config: bufferSize.configuration)
    } else {
      let outputPath = output ?? input + ".lzma"
      try compressFile(
        input: input,
        output: outputPath,
        config: bufferSize.configuration,
        verbose: verbose
      )
    }
  }
}

struct Decompress: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Decompress an LZMA file"
  )

  @Argument(help: "Input file path (use “-” for stdin)")
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
    if input == "-" {
      try decompressStdin(config: bufferSize.configuration)
    } else {
      let outputPath = output ?? defaultDecompressOutput(input)
      try decompressFile(
        input: input,
        output: outputPath,
        config: bufferSize.configuration,
        verbose: verbose
      )
    }
  }
}

// MARK: - Buffer Size

enum BufferSize: String, CaseIterable {
  case small, medium, large, xlarge

  var configuration: LZMAConfiguration {
    switch self {
      case .small: return .compact
      case .medium: return .default
      case .large: return LZMAConfiguration(bufferSize: .large)
      case .xlarge: return .highThroughput
    }
  }

  static func parse(_ str: String) throws -> Self {
    guard let size = Self(rawValue: str.lowercased()) else {
      throw ValidationError("Invalid buffer size: “\(str)”. Use: small, medium, large, or xlarge")
    }
    return size
  }
}

func defaultDecompressOutput(_ input: String) -> String {
  if input.hasSuffix(".lzma") {
    return String(input.dropLast(5))
  }
  return input + ".decompressed"
}

func compressFile(input: String, output: String, config: LZMAConfiguration, verbose: Bool) throws {
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

  try srcHandle.lzmaFileCompress(to: dstHandle, configuration: config, progress: progress)

  if verbose {
    FileHandle.standardError.write(Data("\n".utf8))
  }
}

func decompressFile(input: String, output: String, config: LZMAConfiguration, verbose: Bool) throws
{
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

  try srcHandle.lzmaFileDecompress(to: dstHandle, configuration: config, progress: progress)

  if verbose {
    FileHandle.standardError.write(Data("\n".utf8))
  }
}

func compressStdin(config: LZMAConfiguration) throws {
  let data = FileHandle.standardInput.readDataToEndOfFile()
  guard !data.isEmpty else { return }
  let compressed = try data.lzmaFileCompressed(configuration: config)
  FileHandle.standardOutput.write(compressed)
}

func decompressStdin(config: LZMAConfiguration) throws {
  let data = FileHandle.standardInput.readDataToEndOfFile()
  guard !data.isEmpty else { return }
  let decompressed = try data.lzmaFileDecompressed(configuration: config)
  FileHandle.standardOutput.write(decompressed)
}
