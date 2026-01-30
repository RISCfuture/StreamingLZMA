import Foundation

/// Errors that can occur during LZMA compression or decompression operations.
public enum LZMAError: Error, Sendable, Hashable {
  /// Failed to initialize the compression stream.
  case streamInitializationFailed

  /// Failed to process data during compression or decompression.
  case processingFailed

  /// The input data is corrupted or not valid LZMA data.
  case corruptedData

  /// Empty input was provided where data is required.
  case emptyInput

  /// Failed to allocate memory for buffers.
  case bufferAllocationFailed

  /// The stream has already been finalized and cannot process more data.
  case streamAlreadyFinalized

  /// Invalid configuration parameter.
  case invalidConfiguration(String)

  /// An internal error occurred.
  case internalError(String)
}

extension LZMAError: CustomStringConvertible {
  public var description: String {
    switch self {
      case .streamInitializationFailed:
        return "Failed to initialize LZMA compression stream"
      case .processingFailed:
        return "Failed to process LZMA data"
      case .corruptedData:
        return "Input data is corrupted or not valid LZMA data"
      case .emptyInput:
        return "Empty input provided"
      case .bufferAllocationFailed:
        return "Failed to allocate buffer memory"
      case .streamAlreadyFinalized:
        return "Stream has already been finalized"
      case .invalidConfiguration(let message):
        return "Invalid configuration: \(message)"
      case .internalError(let message):
        return "Internal error: \(message)"
    }
  }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  extension LZMAError: LocalizedError {
    public var errorDescription: String? {
      switch self {
        case .streamInitializationFailed, .processingFailed, .bufferAllocationFailed:
          return String(localized: "LZMA Stream Error", bundle: .module)
        case .corruptedData, .emptyInput:
          return String(localized: "Invalid Input", bundle: .module)
        case .streamAlreadyFinalized:
          return String(localized: "Stream Already Finalized", bundle: .module)
        case .invalidConfiguration:
          return String(localized: "Invalid Configuration", bundle: .module)
        case .internalError:
          return String(localized: "Internal Error", bundle: .module)
      }
    }

    public var failureReason: String? {
      switch self {
        case .streamInitializationFailed:
          return String(
            localized: "Failed to initialize the LZMA compression stream.",
            bundle: .module
          )
        case .processingFailed:
          return String(localized: "An error occurred while processing LZMA data.", bundle: .module)
        case .corruptedData:
          return String(
            localized: "The input data is corrupted or not valid LZMA data.",
            bundle: .module
          )
        case .emptyInput:
          return String(
            localized: "Empty input was provided where data is required.",
            bundle: .module
          )
        case .bufferAllocationFailed:
          return String(
            localized: "Failed to allocate memory for internal buffers.",
            bundle: .module
          )
        case .streamAlreadyFinalized:
          return String(
            localized: "The stream has already been finalized and cannot process more data.",
            bundle: .module
          )
        case .invalidConfiguration(let message):
          return String(localized: "Invalid configuration: \(message)", bundle: .module)
        case .internalError(let message):
          return String(localized: "An internal error occurred: \(message)", bundle: .module)
      }
    }

    public var recoverySuggestion: String? {
      switch self {
        case .corruptedData:
          return String(
            localized:
              "Verify the file is a valid LZMA archive and has not been truncated or modified.",
            bundle: .module
          )
        case .emptyInput:
          return String(
            localized: "Provide non-empty data for compression or decompression.",
            bundle: .module
          )
        case .invalidConfiguration:
          return String(
            localized: "Check configuration values and ensure they are within valid ranges.",
            bundle: .module
          )
        case .streamAlreadyFinalized:
          return String(
            localized:
              "Create a new compressor or decompressor instance to process additional data.",
            bundle: .module
          )
        case .streamInitializationFailed, .processingFailed, .bufferAllocationFailed,
          .internalError:
          return nil
      }
    }
  }
#endif
