import Foundation
import Testing

@testable import StreamingLZMAXZ

@Suite("XZError Tests")
struct XZErrorTests {
  @Test("ioFailure description includes the strerror text")
  func ioFailureDescription() {
    let error = XZError.ioFailure(operation: "write", code: POSIXErrorCode.ENOSPC.rawValue)
    #expect(error.description == "Failed to write: No space left on device")
  }

  @Test("ioFailure bridges to an NSPOSIXErrorDomain underlying error")
  func ioFailureBridgesToPOSIXUnderlyingError() {
    let error = XZError.ioFailure(operation: "write", code: POSIXErrorCode.ENOSPC.rawValue)
    let nsError = error as NSError
    let underlying = try? #require(nsError.userInfo[NSUnderlyingErrorKey] as? NSError)

    #expect(underlying?.domain == NSPOSIXErrorDomain)
    #expect(underlying?.code == Int(POSIXErrorCode.ENOSPC.rawValue))
  }

  @Test("Non-ioFailure cases do not bridge an underlying error")
  func nonIOFailureHasNoUnderlyingError() {
    let nsError = XZError.corruptedData as NSError
    #expect(nsError.userInfo[NSUnderlyingErrorKey] == nil)
  }
}
