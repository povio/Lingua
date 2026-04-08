import XCTest
@testable import LinguaLib

final class RSAPrivateKeyTests: XCTestCase {
  func test_decodePEM_stripsHeaderFooter_andDecodesBase64() throws {
    let payload = Data([0x01, 0x02, 0x03, 0x04])
    let base64 = payload.base64EncodedString()
    let pem = """
    -----BEGIN PRIVATE KEY-----
    \(base64)
    -----END PRIVATE KEY-----
    """
    let decoded = try RSAPrivateKey.decodePEM(pem)
    XCTAssertEqual(decoded, payload)
  }

  func test_decodePEM_whenBodyIsInvalidBase64_throwsInvalidPEM() {
    let pem = """
    -----BEGIN PRIVATE KEY-----
    not_base64!!!
    -----END PRIVATE KEY-----
    """
    XCTAssertThrowsError(try RSAPrivateKey.decodePEM(pem)) { error in
      XCTAssertEqual(error as? RSAPrivateKey.Error, .invalidPEM)
    }
  }

  func test_pkcs1FromPKCS8_extractsInnerOctetString() throws {
    // PKCS#8 wrapping a 4-byte fake "PKCS#1" payload [0xAA, 0xBB, 0xCC, 0xDD].
    let pkcs1: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD]
    var inner: [UInt8] = []
    // version INTEGER 0
    inner.append(contentsOf: [0x02, 0x01, 0x00])
    // AlgorithmIdentifier SEQUENCE { OID rsaEncryption, NULL }
    inner.append(contentsOf: [0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00])
    // OCTET STRING wrapping pkcs1
    inner.append(contentsOf: [0x04, UInt8(pkcs1.count)])
    inner.append(contentsOf: pkcs1)
    var pkcs8: [UInt8] = [0x30, UInt8(inner.count)]
    pkcs8.append(contentsOf: inner)

    let extracted = try RSAPrivateKey.pkcs1FromPKCS8(Data(pkcs8))
    XCTAssertEqual(Array(extracted), pkcs1)
  }

  func test_pkcs1FromPKCS8_whenOuterIsNotSequence_throwsInvalidDER() {
    XCTAssertThrowsError(try RSAPrivateKey.pkcs1FromPKCS8(Data([0x02, 0x01, 0x00]))) { error in
      XCTAssertEqual(error as? RSAPrivateKey.Error, .invalidDER)
    }
  }

  func test_signRS256_withGeneratedKey_producesNonEmptySignature() throws {
    let pem = TestRSAKey.generatePEMPrivateKey()
    let payload = Data("hello world".utf8)
    let signature = try RSAPrivateKey.signRS256(payload: payload, pemPrivateKey: pem)
    // RS256 signatures with a 2048-bit key are 256 bytes long.
    XCTAssertEqual(signature.count, 256)
  }

  func test_signRS256_withInvalidPEM_throws() {
    XCTAssertThrowsError(try RSAPrivateKey.signRS256(payload: Data("x".utf8), pemPrivateKey: "not a pem"))
  }

  func test_base64URLEncodedString_replacesUnsafeCharactersAndStripsPadding() {
    // 0xFB, 0xFF produce "+/8=" in standard base64.
    let data = Data([0xFB, 0xFF])
    XCTAssertEqual(data.base64EncodedString(), "+/8=")
    XCTAssertEqual(data.base64URLEncodedString(), "-_8")
  }

  func test_errorDescriptions_areLocalized() {
    XCTAssertNotNil(RSAPrivateKey.Error.invalidPEM.errorDescription)
    XCTAssertNotNil(RSAPrivateKey.Error.invalidDER.errorDescription)
    XCTAssertNotNil(RSAPrivateKey.Error.unsupportedPlatform.errorDescription)
    XCTAssertEqual(RSAPrivateKey.Error.signingFailed("boom").errorDescription, "RSA signing failed: boom")
  }
}

extension RSAPrivateKey.Error: Equatable {
  public static func == (lhs: RSAPrivateKey.Error, rhs: RSAPrivateKey.Error) -> Bool {
    switch (lhs, rhs) {
    case (.invalidPEM, .invalidPEM),
         (.invalidDER, .invalidDER),
         (.unsupportedPlatform, .unsupportedPlatform):
      return true
    case let (.signingFailed(a), .signingFailed(b)):
      return a == b
    default:
      return false
    }
  }
}
