import Foundation
#if canImport(Security)
import Security
#endif

/// Generates throwaway PEM-encoded RSA private keys for tests. The key only exists
/// inside the test process and is never persisted.
enum TestRSAKey {
  static func generatePEMPrivateKey(bits: Int = 2048) -> String {
    #if canImport(Security)
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeySizeInBits as String: bits
    ]
    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      fatalError("RSA key generation failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
    }
    guard let pkcs1Data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
      fatalError("RSA key export failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
    }
    let pkcs8 = wrapPKCS1AsPKCS8(pkcs1Data)
    let base64 = pkcs8.base64EncodedString()
    let chunked = stride(from: 0, to: base64.count, by: 64).map { offset -> String in
      let start = base64.index(base64.startIndex, offsetBy: offset)
      let end = base64.index(start, offsetBy: 64, limitedBy: base64.endIndex) ?? base64.endIndex
      return String(base64[start..<end])
    }.joined(separator: "\n")
    return "-----BEGIN PRIVATE KEY-----\n\(chunked)\n-----END PRIVATE KEY-----"
    #else
    fatalError("RSA key generation requires the Security framework")
    #endif
  }

  /// PKCS#8 PrivateKeyInfo := SEQUENCE { version INTEGER 0, algorithm AlgorithmIdentifier, privateKey OCTET STRING }
  /// Where algorithm is rsaEncryption (1.2.840.113549.1.1.1) NULL.
  private static func wrapPKCS1AsPKCS8(_ pkcs1: Data) -> Data {
    let version: [UInt8] = [0x02, 0x01, 0x00]
    let algorithm: [UInt8] = [
      0x30, 0x0D,
      0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,
      0x05, 0x00
    ]
    var octet: [UInt8] = [0x04]
    octet.append(contentsOf: derLength(pkcs1.count))
    octet.append(contentsOf: [UInt8](pkcs1))

    var inner: [UInt8] = []
    inner.append(contentsOf: version)
    inner.append(contentsOf: algorithm)
    inner.append(contentsOf: octet)

    var outer: [UInt8] = [0x30]
    outer.append(contentsOf: derLength(inner.count))
    outer.append(contentsOf: inner)
    return Data(outer)
  }

  private static func derLength(_ length: Int) -> [UInt8] {
    if length < 0x80 { return [UInt8(length)] }
    var bytes: [UInt8] = []
    var n = length
    while n > 0 {
      bytes.insert(UInt8(n & 0xFF), at: 0)
      n >>= 8
    }
    return [0x80 | UInt8(bytes.count)] + bytes
  }
}
