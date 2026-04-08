import Foundation
#if canImport(Security)
import Security
#endif

/// Parses a PEM-encoded PKCS#8 RSA private key (the format Google service account JSON uses)
/// and signs payloads using RS256 via the Security framework.
enum RSAPrivateKey {
  enum Error: Swift.Error, LocalizedError, Equatable {
    case invalidPEM
    case invalidDER
    case unsupportedPlatform
    case signingFailed(String)

    var errorDescription: String? {
      switch self {
      case .invalidPEM: return "Service account private key is not a valid PEM block."
      case .invalidDER: return "Service account private key DER is malformed."
      case .unsupportedPlatform: return "RSA signing is not supported on this platform."
      case .signingFailed(let m): return "RSA signing failed: \(m)"
      }
    }
  }

  /// Strips the PEM header/footer and base64-decodes the body.
  static func decodePEM(_ pem: String) throws -> Data {
    let lines = pem
      .split(whereSeparator: \.isNewline)
      .map(String.init)
      .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
    let base64 = lines.joined()
    guard let data = Data(base64Encoded: base64) else {
      throw Error.invalidPEM
    }
    return data
  }

  /// Service account keys are PKCS#8. Convert to PKCS#1 (which `SecKeyCreateWithData` expects)
  /// by stripping the AlgorithmIdentifier wrapper.
  static func pkcs1FromPKCS8(_ pkcs8: Data) throws -> Data {
    let bytes = [UInt8](pkcs8)
    var i = 0

    // Outer SEQUENCE
    guard i < bytes.count, bytes[i] == 0x30 else { throw Error.invalidDER }
    i += 1
    _ = try readLength(bytes, &i)

    // Version INTEGER (0)
    guard i < bytes.count, bytes[i] == 0x02 else { throw Error.invalidDER }
    i += 1
    let versionLen = try readLength(bytes, &i)
    i += versionLen

    // Algorithm SEQUENCE (skip)
    guard i < bytes.count, bytes[i] == 0x30 else { throw Error.invalidDER }
    i += 1
    let algoLen = try readLength(bytes, &i)
    i += algoLen

    // OCTET STRING containing the PKCS#1 key
    guard i < bytes.count, bytes[i] == 0x04 else { throw Error.invalidDER }
    i += 1
    let octetLen = try readLength(bytes, &i)
    guard i + octetLen <= bytes.count else { throw Error.invalidDER }
    return Data(bytes[i..<(i + octetLen)])
  }

  private static func readLength(_ bytes: [UInt8], _ i: inout Int) throws -> Int {
    guard i < bytes.count else { throw Error.invalidDER }
    let first = bytes[i]
    i += 1
    if first & 0x80 == 0 {
      return Int(first)
    }
    let count = Int(first & 0x7F)
    guard count > 0, i + count <= bytes.count else { throw Error.invalidDER }
    var len = 0
    for _ in 0..<count {
      len = (len << 8) | Int(bytes[i])
      i += 1
    }
    return len
  }

  /// Sign `payload` with the given PEM private key using RS256.
  static func signRS256(payload: Data, pemPrivateKey: String) throws -> Data {
    #if canImport(Security)
    let pkcs8 = try decodePEM(pemPrivateKey)
    let pkcs1 = try pkcs1FromPKCS8(pkcs8)

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
    ]

    var unmanagedError: Unmanaged<CFError>?
    guard let secKey = SecKeyCreateWithData(pkcs1 as CFData, attributes as CFDictionary, &unmanagedError) else {
      let msg = (unmanagedError?.takeRetainedValue() as Swift.Error?)?.localizedDescription ?? "unknown"
      throw Error.signingFailed("could not create key: \(msg)")
    }

    var signError: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
      secKey,
      .rsaSignatureMessagePKCS1v15SHA256,
      payload as CFData,
      &signError
    ) else {
      let msg = (signError?.takeRetainedValue() as Swift.Error?)?.localizedDescription ?? "unknown"
      throw Error.signingFailed(msg)
    }

    return signature as Data
    #else
    throw Error.unsupportedPlatform
    #endif
  }
}

extension Data {
  /// URL-safe base64 without padding (per JWT spec).
  func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
