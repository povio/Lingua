import XCTest
@testable import LinguaLib

final class ServiceAccountTokenProviderTests: XCTestCase {
  override func tearDown() {
    HandlerURLProtocol.setHandler(nil)
    super.tearDown()
  }

  func test_token_exchangesJWTAndReturnsAccessToken() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      let payload = #"{"access_token":"abc-123","expires_in":3600}"#
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
    }

    let key = makeServiceAccountKey()
    let sut = makeSUT(key: key)
    let token = try await sut.token()

    XCTAssertEqual(token, "abc-123")
    let request = try XCTUnwrap(recorder.requests.first)
    XCTAssertEqual(request.url?.absoluteString, key.tokenUri)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
    let body = String(data: try XCTUnwrap(recorder.bodies.first), encoding: .utf8) ?? ""
    XCTAssertTrue(body.hasPrefix("grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion="))
    let assertion = body.replacingOccurrences(of: "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=", with: "")
    let segments = assertion.split(separator: ".")
    XCTAssertEqual(segments.count, 3)
  }

  func test_token_isCachedBetweenCalls() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      let payload = #"{"access_token":"cached","expires_in":3600}"#
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
    }
    let sut = makeSUT(key: makeServiceAccountKey())

    let first = try await sut.token()
    let second = try await sut.token()

    XCTAssertEqual(first, "cached")
    XCTAssertEqual(second, "cached")
    XCTAssertEqual(recorder.requests.count, 1)
  }

  func test_token_whenCacheNearlyExpired_refetches() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      // expires_in: 30 means cachedExpiry - 60s < now → cache treated as stale immediately.
      let payload = #"{"access_token":"short","expires_in":30}"#
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
    }
    let sut = makeSUT(key: makeServiceAccountKey())

    _ = try await sut.token()
    _ = try await sut.token()

    XCTAssertEqual(recorder.requests.count, 2)
  }

  func test_token_whenServerReturnsError_throwsAgentError() async {
    HandlerURLProtocol.setHandler { request in
      (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data("denied".utf8))
    }
    let sut = makeSUT(key: makeServiceAccountKey())
    do {
      _ = try await sut.token()
      XCTFail("expected error")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "service_account_auth_failed")
      XCTAssertTrue(error.message.contains("denied"))
    } catch {
      XCTFail("expected AgentError, got \(error)")
    }
  }
}

private extension ServiceAccountTokenProviderTests {
  func makeSUT(key: ServiceAccountKey) -> ServiceAccountTokenProvider {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [HandlerURLProtocol.self]
    let session = URLSession(configuration: configuration)
    return ServiceAccountTokenProvider(key: key, urlSession: session)
  }

  func makeServiceAccountKey(tokenUri: String = "https://oauth2.googleapis.com/token") -> ServiceAccountKey {
    let pem = TestRSAKey.generatePEMPrivateKey()
    let json = """
    {
      "type": "service_account",
      "project_id": "test-project",
      "private_key_id": "test-key-id",
      "private_key": \(jsonString(pem)),
      "client_email": "test@test.iam.gserviceaccount.com",
      "token_uri": "\(tokenUri)"
    }
    """
    return try! JSONDecoder().decode(ServiceAccountKey.self, from: Data(json.utf8))
  }

  func jsonString(_ raw: String) -> String {
    let data = try! JSONSerialization.data(withJSONObject: [raw], options: [])
    let array = String(data: data, encoding: .utf8)!
    // strip leading "[" and trailing "]"
    return String(array.dropFirst().dropLast())
  }
}
