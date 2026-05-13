import XCTest
@testable import LinguaLib

final class GoogleSheetsWriterTests: XCTestCase {
  override func tearDown() {
    HandlerURLProtocol.setHandler(nil)
    super.tearDown()
  }

  // MARK: - columnLetters

  func test_columnLetters_mapsIndicesToLetters() {
    XCTAssertEqual(GoogleSheetsWriter.columnLetters(forIndex: 1), "A")
    XCTAssertEqual(GoogleSheetsWriter.columnLetters(forIndex: 26), "Z")
    XCTAssertEqual(GoogleSheetsWriter.columnLetters(forIndex: 27), "AA")
    XCTAssertEqual(GoogleSheetsWriter.columnLetters(forIndex: 52), "AZ")
    XCTAssertEqual(GoogleSheetsWriter.columnLetters(forIndex: 0), "A") // clamps to 1
  }

  // MARK: - updateRow

  func test_updateRow_putsValuesAtComputedRange() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
    }

    let sut = makeSUT(sheetId: "SHEET")
    try await sut.updateRow(sheetTab: "Tab Name", oneBasedRowIndex: 5, cells: ["a", "b", "c"])

    XCTAssertEqual(recorder.requests.count, 1)
    let request = try XCTUnwrap(recorder.requests.first)
    XCTAssertEqual(request.httpMethod, "PUT")
    let url = try XCTUnwrap(request.url)
    let path = url.path
    XCTAssertTrue(path.contains("/spreadsheets/SHEET/values/"), "path was: \(path)")
    XCTAssertTrue(path.contains("Tab Name!A5:C5"), "path was: \(path)")
    XCTAssertEqual(url.query, "valueInputOption=RAW")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")

    let body = try XCTUnwrap(recorder.bodies.first)
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(json["range"] as? String, "Tab Name!A5:C5")
    XCTAssertEqual(json["majorDimension"] as? String, "ROWS")
    let values = try XCTUnwrap(json["values"] as? [[String]])
    XCTAssertEqual(values, [["a", "b", "c"]])
  }

  func test_updateRow_whenServerReturnsError_throwsAgentError() async {
    HandlerURLProtocol.setHandler { request in
      (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data("boom".utf8))
    }
    let sut = makeSUT()
    do {
      try await sut.updateRow(sheetTab: "Tab", oneBasedRowIndex: 1, cells: ["x"])
      XCTFail("expected error")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "google_sheets_write_failed")
      XCTAssertTrue(error.message.contains("boom"))
    } catch {
      XCTFail("expected AgentError, got \(error)")
    }
  }

  // MARK: - appendRow

  func test_appendRow_postsToAppendEndpoint() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
    }

    let sut = makeSUT(sheetId: "SHEET")
    try await sut.appendRow(sheetTab: "Tab", cells: ["x", "y"])

    let request = try XCTUnwrap(recorder.requests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    let url = try XCTUnwrap(request.url)
    XCTAssertTrue(url.path.contains("Tab!A:Z:append"), "path was: \(url.path)")
    let query = url.query ?? ""
    XCTAssertTrue(query.contains("valueInputOption=RAW"))
    XCTAssertTrue(query.contains("insertDataOption=INSERT_ROWS"))

    let body = try XCTUnwrap(recorder.bodies.first)
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(json["values"] as? [[String]], [["x", "y"]])
  }

  // MARK: - updateCell

  func test_updateCell_writesToCellRange() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
    }

    let sut = makeSUT(sheetId: "SHEET")
    try await sut.updateCell(sheetTab: "Tab", oneBasedRow: 3, oneBasedColumn: 27, value: "v")

    let request = try XCTUnwrap(recorder.requests.first)
    let url = try XCTUnwrap(request.url)
    XCTAssertTrue(url.path.contains("Tab!AA3"), "path was: \(url.path)")

    let body = try XCTUnwrap(recorder.bodies.first)
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(json["range"] as? String, "Tab!AA3")
    XCTAssertEqual(json["values"] as? [[String]], [["v"]])
  }

  // MARK: - insertRow

  func test_insertRow_fetchesGid_thenBatchUpdates_thenWritesValues() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      let url = request.url!.absoluteString
      if url.contains("?fields=sheets.properties") {
        let payload = """
        {"sheets":[{"properties":{"sheetId":42,"title":"Tab"}}]}
        """
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
      }
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
    }

    let sut = makeSUT(sheetId: "SHEET")
    try await sut.insertRow(sheetTab: "Tab", oneBasedRowIndex: 4, cells: ["a", "b"])

    XCTAssertEqual(recorder.requests.count, 3)
    let metadata = recorder.requests[0]
    XCTAssertEqual(metadata.httpMethod ?? "GET", "GET")
    XCTAssertTrue(metadata.url!.absoluteString.contains("?fields=sheets.properties"))

    let batch = recorder.requests[1]
    XCTAssertEqual(batch.httpMethod, "POST")
    XCTAssertTrue(batch.url!.absoluteString.hasSuffix(":batchUpdate"))
    let batchBody = try XCTUnwrap(recorder.bodies[1])
    let batchJson = try XCTUnwrap(try JSONSerialization.jsonObject(with: batchBody) as? [String: Any])
    let requests = try XCTUnwrap(batchJson["requests"] as? [[String: Any]])
    let insertDimension = try XCTUnwrap(requests.first?["insertDimension"] as? [String: Any])
    let range = try XCTUnwrap(insertDimension["range"] as? [String: Any])
    XCTAssertEqual(range["sheetId"] as? Int, 42)
    XCTAssertEqual(range["dimension"] as? String, "ROWS")
    XCTAssertEqual(range["startIndex"] as? Int, 3)
    XCTAssertEqual(range["endIndex"] as? Int, 4)
    XCTAssertEqual(insertDimension["inheritFromBefore"] as? Bool, true)

    let writeRequest = recorder.requests[2]
    XCTAssertEqual(writeRequest.httpMethod, "PUT")
    XCTAssertTrue(writeRequest.url!.path.contains("Tab!A4:B4"), "path was: \(writeRequest.url!.path)")
  }

  func test_insertRow_atFirstRow_doesNotInheritFromBefore() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      let url = request.url!.absoluteString
      if url.contains("?fields=sheets.properties") {
        let payload = """
        {"sheets":[{"properties":{"sheetId":7,"title":"Tab"}}]}
        """
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
      }
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
    }

    let sut = makeSUT()
    try await sut.insertRow(sheetTab: "Tab", oneBasedRowIndex: 1, cells: ["x"])

    let batchBody = try XCTUnwrap(recorder.bodies[1])
    let batchJson = try XCTUnwrap(try JSONSerialization.jsonObject(with: batchBody) as? [String: Any])
    let requests = try XCTUnwrap(batchJson["requests"] as? [[String: Any]])
    let insertDimension = try XCTUnwrap(requests.first?["insertDimension"] as? [String: Any])
    XCTAssertEqual(insertDimension["inheritFromBefore"] as? Bool, false)
  }

  func test_insertRow_whenTabUnknown_throwsSheetTabNotFound() async {
    HandlerURLProtocol.setHandler { request in
      let payload = """
      {"sheets":[{"properties":{"sheetId":1,"title":"Other"}}]}
      """
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
    }
    let sut = makeSUT()
    do {
      try await sut.insertRow(sheetTab: "Missing", oneBasedRowIndex: 2, cells: ["x"])
      XCTFail("expected error")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "sheet_tab_not_found")
    } catch {
      XCTFail("expected AgentError, got \(error)")
    }
  }

  func test_insertRow_whenMetadataFails_throwsMetadataFetchFailed() async {
    HandlerURLProtocol.setHandler { request in
      (HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!, Data("nope".utf8))
    }
    let sut = makeSUT()
    do {
      try await sut.insertRow(sheetTab: "Tab", oneBasedRowIndex: 1, cells: ["x"])
      XCTFail("expected error")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "metadata_fetch_failed")
      XCTAssertTrue(error.message.contains("nope"))
    } catch {
      XCTFail("expected AgentError, got \(error)")
    }
  }

  func test_insertRow_cachesGidAcrossCalls() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      let url = request.url!.absoluteString
      if url.contains("?fields=sheets.properties") {
        let payload = """
        {"sheets":[{"properties":{"sheetId":1,"title":"Tab"}}]}
        """
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
      }
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
    }

    let sut = makeSUT()
    try await sut.insertRow(sheetTab: "Tab", oneBasedRowIndex: 2, cells: ["a"])
    try await sut.insertRow(sheetTab: "Tab", oneBasedRowIndex: 3, cells: ["b"])

    let metadataCalls = recorder.requests.filter { $0.url!.absoluteString.contains("?fields=sheets.properties") }
    XCTAssertEqual(metadataCalls.count, 1)
  }

  // MARK: - deleteRow

  func test_deleteRow_sendsDeleteDimensionRequest() async throws {
    let recorder = RequestRecorder()
    HandlerURLProtocol.setHandler { request in
      recorder.record(request)
      let url = request.url!.absoluteString
      if url.contains("?fields=sheets.properties") {
        let payload = """
        {"sheets":[{"properties":{"sheetId":11,"title":"Tab"}}]}
        """
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
      }
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
    }

    let sut = makeSUT()
    try await sut.deleteRow(sheetTab: "Tab", oneBasedRowIndex: 9)

    let batch = try XCTUnwrap(recorder.requests.last)
    XCTAssertTrue(batch.url!.absoluteString.hasSuffix(":batchUpdate"))
    let body = try XCTUnwrap(recorder.bodies.last)
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    let requests = try XCTUnwrap(json["requests"] as? [[String: Any]])
    let deleteDimension = try XCTUnwrap(requests.first?["deleteDimension"] as? [String: Any])
    let range = try XCTUnwrap(deleteDimension["range"] as? [String: Any])
    XCTAssertEqual(range["sheetId"] as? Int, 11)
    XCTAssertEqual(range["startIndex"] as? Int, 8)
    XCTAssertEqual(range["endIndex"] as? Int, 9)
  }
}

// MARK: - Test helpers

private extension GoogleSheetsWriterTests {
  func makeSUT(sheetId: String = "SHEET") -> GoogleSheetsWriter {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [HandlerURLProtocol.self]
    let session = URLSession(configuration: configuration)
    return GoogleSheetsWriter(
      sheetId: sheetId,
      tokenProvider: StubAccessTokenProvider(token: "test-token"),
      urlSession: session
    )
  }
}

final class StubAccessTokenProvider: AccessTokenProviding {
  private let stubbedToken: String
  init(token: String) { self.stubbedToken = token }
  func token() async throws -> String { stubbedToken }
}

final class RequestRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private(set) var requests: [URLRequest] = []
  private(set) var bodies: [Data] = []

  func record(_ request: URLRequest) {
    lock.lock(); defer { lock.unlock() }
    requests.append(request)
    // URLProtocol strips httpBody — read from BodyStream when needed.
    if let body = request.httpBody {
      bodies.append(body)
    } else if let stream = request.httpBodyStream {
      bodies.append(Self.readStream(stream))
    } else {
      bodies.append(Data())
    }
  }

  private static func readStream(_ stream: InputStream) -> Data {
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
      let read = stream.read(buffer, maxLength: bufferSize)
      if read <= 0 { break }
      data.append(buffer, count: read)
    }
    return data
  }
}
