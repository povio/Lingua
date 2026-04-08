import Foundation

/// URLProtocol stub that defers each request to a closure. Use when a test needs to
/// inspect the request or return different responses across multiple calls (something
/// the static `MockURLProtocol` cannot model).
final class HandlerURLProtocol: URLProtocol {
  typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

  private static let lock = NSLock()
  private static var _handler: Handler?

  static func setHandler(_ handler: Handler?) {
    lock.lock(); defer { lock.unlock() }
    _handler = handler
  }

  private static func currentHandler() -> Handler? {
    lock.lock(); defer { lock.unlock() }
    return _handler
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = HandlerURLProtocol.currentHandler() else {
      client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
      return
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
