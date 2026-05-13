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
  
  func test_fetchDataWithRequest_returnsDataAndResponse() async throws {
    let (sut, url) = makeSUT()
    let expectedData: Data = .anyData(string: "payload")
    MockURLProtocol.mockData = expectedData
    MockURLProtocol.mockError = nil
    MockURLProtocol.mockResponse = HTTPURLResponse.anyURLResponse(statusCode: 201)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = Data("body".utf8)
    let (data, response) = try await sut.fetchData(with: request)

    XCTAssertEqual(data, expectedData)
    XCTAssertEqual(response.statusCode, 201)
  }

  func test_fetchDataWithRequest_whenResponseIsNotHTTPURLResponse_throwsInvalidHTTPResponseError() async {
    let (sut, url) = makeSUT()
    MockURLProtocol.mockData = Data("body".utf8)
    MockURLProtocol.mockError = nil
    MockURLProtocol.mockResponse = CustomURLResponse()

    do {
      _ = try await sut.fetchData(with: URLRequest(url: url))
      XCTFail("expected error")
    } catch let error as InvalidHTTPResponseError {
      XCTAssertEqual(error.statusCode, 0)
      XCTAssertEqual(error.data, Data("body".utf8))
    } catch {
      XCTFail("expected InvalidHTTPResponseError, got \(error)")
    }
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
