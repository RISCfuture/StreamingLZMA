import Testing
@testable import StreamingLZMA

@Suite("LZMAFileHeader Tests")
struct LZMAFileHeaderTests {
  @Test("Header encodes to 13 bytes")
  func headerEncodesTo13Bytes() {
    let header = LZMAFileHeader.default
    let encoded = header.encoded()
    #expect(encoded.count == 13)
  }

  @Test("Header round-trips through encoding")
  func headerRoundTrip() throws {
    let original = LZMAFileHeader(
      properties: 0x5D,
      dictionarySize: 4_194_304,
      uncompressedSize: 999_999
    )

    let encoded = original.encoded()
    let decoded = try LZMAFileHeader(from: encoded)

    #expect(decoded.properties == original.properties)
    #expect(decoded.dictionarySize == original.dictionarySize)
    #expect(decoded.uncompressedSize == original.uncompressedSize)
  }

  @Test("Parsing short data throws corruptedData")
  func parseShortDataThrows() {
    let shortData = Data([0x5D, 0x00])
    #expect(throws: LZMAError.corruptedData) {
      try LZMAFileHeader(from: shortData)
    }
  }

  @Test("Properties decode correctly")
  func propertiesDecode() {
    // 0x5D = 93 = 2*45 + 0*9 + 3 -> pb=2, lp=0, lc=3
    let header = LZMAFileHeader.default
    let (lc, lp, pb) = header.decodedProperties
    #expect(lc == 3)
    #expect(lp == 0)
    #expect(pb == 2)
  }

  @Test("Encoded header has correct byte order")
  func encodedHeaderByteOrder() {
    let header = LZMAFileHeader(
      properties: 0x5D,
      dictionarySize: 0x00800000,  // 8 MB
      uncompressedSize: 0x0000000000001234
    )

    let encoded = header.encoded()

    // Properties byte
    #expect(encoded[0] == 0x5D)

    // Dictionary size (little-endian): 0x00800000
    #expect(encoded[1] == 0x00)
    #expect(encoded[2] == 0x00)
    #expect(encoded[3] == 0x80)
    #expect(encoded[4] == 0x00)

    // Uncompressed size (little-endian): 0x1234
    #expect(encoded[5] == 0x34)
    #expect(encoded[6] == 0x12)
    #expect(encoded[7] == 0x00)
    #expect(encoded[8] == 0x00)
    #expect(encoded[9] == 0x00)
    #expect(encoded[10] == 0x00)
    #expect(encoded[11] == 0x00)
    #expect(encoded[12] == 0x00)
  }
}
