import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol AccessTokenProviding {
  func token() async throws -> String
}

/// Builds and signs a JWT for a Google service account, exchanges it at the OAuth2 token
/// endpoint, and caches the resulting access token in memory until just before it expires.
final class ServiceAccountTokenProvider: AccessTokenProviding {
  private let key: ServiceAccountKey
  private let scope: String
  private let urlSession: URLSession
  private var cachedToken: String?
  private var cachedExpiry: Date = .distantPast

  init(key: ServiceAccountKey,
       scope: String = "https://www.googleapis.com/auth/spreadsheets",
       urlSession: URLSession = .shared) {
    self.key = key
    self.scope = scope
    self.urlSession = urlSession
  }

  func token() async throws -> String {
    if let cached = cachedToken, Date() < cachedExpiry.addingTimeInterval(-60) {
      return cached
    }

    let now = Date()
    let exp = now.addingTimeInterval(3600)

    let header = ["alg": "RS256", "typ": "JWT"]
    let claims: [String: Any] = [
      "iss": key.clientEmail,
      "scope": scope,
      "aud": key.tokenUri,
      "iat": Int(now.timeIntervalSince1970),
      "exp": Int(exp.timeIntervalSince1970)
    ]

    let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
    let claimsData = try JSONSerialization.data(withJSONObject: claims, options: [.sortedKeys])

    let signingInput = "\(headerData.base64URLEncodedString()).\(claimsData.base64URLEncodedString())"
    guard let signingInputData = signingInput.data(using: .utf8) else {
      throw AgentError(code: "jwt_encode_failed", message: "Could not UTF-8 encode JWT signing input.")
    }

    let signature = try RSAPrivateKey.signRS256(payload: signingInputData, pemPrivateKey: key.privateKey)
    let jwt = "\(signingInput).\(signature.base64URLEncodedString())"

    var request = URLRequest(url: URL(string: key.tokenUri)!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"
    request.httpBody = body.data(using: .utf8)

    let (data, response) = try await urlSession.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
      throw AgentError(
        code: "service_account_auth_failed",
        message: "Could not exchange JWT for access token. Response: \(bodyText)"
      )
    }

    struct TokenResponse: Decodable {
      let access_token: String
      let expires_in: Int
    }
    let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
    cachedToken = decoded.access_token
    cachedExpiry = Date().addingTimeInterval(TimeInterval(decoded.expires_in))
    return decoded.access_token
  }
}
