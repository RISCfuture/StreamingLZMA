import Foundation

/// Errors that can occur during XZ compression or decompression operations.
public enum XZError: Error, Sendable, Hashable {
  /// Failed to initialize the compression stream.
  case streamInitializationFailed

  /// Failed to process data during compression or decompression.
  case processingFailed

  /// The input data is corrupted or not valid XZ data.
  case corruptedData

  /// Empty input was provided where data is required.
  case emptyInput

  /// Failed to allocate memory for buffers.
  case memoryError

  /// The integrity check type is not supported.
  case unsupportedCheck

  /// The stream has already been finalized and cannot process more data.
  case streamAlreadyFinalized

  /// An internal error occurred.
  case internalError(String)
}

extension XZError: CustomStringConvertible {
  public var description: String {
    switch self {
      case .streamInitializationFailed:
        return "Failed to initialize XZ compression stream"
      case .processingFailed:
        return "Failed to process XZ data"
      case .corruptedData:
        return "Input data is corrupted or not valid XZ data"
      case .emptyInput:
        return "Empty input provided"
      case .memoryError:
        return "Failed to allocate memory"
      case .unsupportedCheck:
        return "Unsupported integrity check type"
      case .streamAlreadyFinalized:
        return "Stream has already been finalized"
      case .internalError(let message):
        return "Internal error: \(message)"
    }
  }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  extension XZError: LocalizedError {
    public var errorDescription: String? {
      switch self {
        case .streamInitializationFailed, .processingFailed, .memoryError:
          return String(localized: "XZ Stream Error", bundle: .module)
        case .corruptedData, .emptyInput:
          return String(localized: "Invalid Input", bundle: .module)
        case .unsupportedCheck:
          return String(localized: "Unsupported Check Type", bundle: .module)
        case .streamAlreadyFinalized:
          return String(localized: "Stream Already Finalized", bundle: .module)
        case .internalError:
          return String(localized: "Internal Error", bundle: .module)
      }
    }

    public var failureReason: String? {
      switch self {
        case .streamInitializationFailed:
          return String(
            localized: "Failed to initialize the XZ compression stream.",
            bundle: .module
          )
        case .processingFailed:
          return String(localized: "An error occurred while processing XZ data.", bundle: .module)
        case .corruptedData:
          return String(
            localized: "The input data is corrupted or not valid XZ data.",
            bundle: .module
          )
        case .emptyInput:
          return String(
            localized: "Empty input was provided where data is required.",
            bundle: .module
          )
        case .memoryError:
          return String(
            localized: "Failed to allocate memory for internal operations.",
            bundle: .module
          )
        case .unsupportedCheck:
          return String(
            localized: "The integrity check type specified is not supported.",
            bundle: .module
          )
        case .streamAlreadyFinalized:
          return String(
            localized: "The stream has already been finalized and cannot process more data.",
            bundle: .module
          )
        case .internalError(let message):
          return String(localized: "An internal error occurred: \(message)", bundle: .module)
      }
    }

    public var recoverySuggestion: String? {
      switch self {
        case .corruptedData:
          return String(
            localized:
              "Verify the file is a valid XZ archive and has not been truncated or modified.",
            bundle: .module
          )
        case .emptyInput:
          return String(
            localized: "Provide non-empty data for compression or decompression.",
            bundle: .module
          )
        case .streamAlreadyFinalized:
          return String(
            localized:
              "Create a new compressor or decompressor instance to process additional data.",
            bundle: .module
          )
        case .unsupportedCheck:
          return String(
            localized: "Use a supported integrity check type such as CRC32, CRC64, or SHA-256.",
            bundle: .module
          )
        case .streamInitializationFailed, .processingFailed, .memoryError, .internalError:
          return nil
      }
    }
  }
#endif
