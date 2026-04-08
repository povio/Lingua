import XCTest
@testable import LinguaLib

final class URLSessionHTTPClientTests: XCTestCase {
  func test_fetchData_whenRequestSucceeds_returnsDataAndResponse() async throws {
    let (sut, url) = makeSUT()
    let expectedData: Data = .anyData()
    let successStatusCode = 200
    
    MockURLProtocol.mockData = expectedData
    MockURLProtocol.mockError = nil
    MockURLProtocol.mockResponse = HTTPURLResponse.anyURLResponse(statusCode: successStatusCode)
    
    let (receivedData, receivedResponse) = try await sut.fetchData(from: url)
    XCTAssertEqual(receivedData, expectedData)
    XCTAssertEqual(receivedResponse.statusCode, successStatusCode)
  }
  
  func test_fetchData_whenRequestFails_throwsError() async {
    let (sut, url) = makeSUT()
    let expectedError: NSError = .anyError()
    
    MockURLProtocol.mockData = nil
    MockURLProtocol.mockError = expectedError
    MockURLProtocol.mockResponse = nil
    
    do {
      _ = try await sut.fetchData(from: url)
      XCTFail("Expected error to be thrown")
    } catch {
      let error = error as NSError
      XCTAssertEqual(error.domain, expectedError.domain)
      XCTAssertEqual(error.code, expectedError.code)
    }
  }
  
  func test_fetchDataFromURL_withNon200HTTPResponse_throwsInvalidHTTPResponseError() async throws {
    let (sut, url) = makeSUT()
    
    let non200StatusCode = 404
    MockURLProtocol.mockData = Data()
    MockURLProtocol.mockResponse = HTTPURLResponse.anyURLResponse(statusCode: non200StatusCode)
    
    let (_, receivedResponse) = try await sut.fetchData(from: url)
    XCTAssertEqual(receivedResponse.statusCode, non200StatusCode)
  }
  
  func test_fetchData_whenResponseIsNotHTTPURLResponse_throwsInvalidHTTPResponseError() async throws {
    let (sut, url) = makeSUT()
    
    let customResponse = CustomURLResponse()
    MockURLProtocol.mockData = Data()
    MockURLProtocol.mockResponse = customResponse
    
    do {
      _ = try await sut.fetchData(from: url)
      XCTFail("Expected InvalidHTTPResponseError to be thrown")
    } catch {
      let error = try XCTUnwrap(error as? InvalidHTTPResponseError)
      XCTAssertEqual(error.statusCode, 0)
      XCTAssertNil(CustomURLResponse(coder: NSCoder()))
    }
  }
}

private extension URLSessionHTTPClientTests {
  func makeSUT() -> (sut: URLSessionHTTPClient, url: URL) {
    let url: URL = .anyURL()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    let sut = URLSessionHTTPClient(urlSession: urlSession)
    
    return (sut, url)
  }
  
  class CustomURLResponse: URLResponse, @unchecked Sendable {
    init() {
      super.init(url: .anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
      nil
    }
  }
}
