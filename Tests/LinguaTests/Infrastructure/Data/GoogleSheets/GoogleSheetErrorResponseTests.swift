import XCTest
@testable import LinguaLib

final class GoogleSheetErrorResponseTests: XCTestCase {
  func test_decoding_parsesPermissionDenied() throws {
    let json = """
    {
      "error": {
        "code": 403,
        "message": "Permission denied",
        "status": "PERMISSION_DENIED"
      }
    }
    """
    let decoded = try JSONDecoder().decode(GoogleSheetErrorResponse.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.error.code, 403)
    XCTAssertEqual(decoded.error.message, "Permission denied")
    XCTAssertEqual(decoded.error.status, .permissionDenied)
  }

  func test_decoding_parsesNotFound() throws {
    let json = #"{"error":{"code":404,"message":"Not found","status":"NOT_FOUND"}}"#
    let decoded = try JSONDecoder().decode(GoogleSheetErrorResponse.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.error.status, .notFound)
  }

  func test_decoding_parsesInvalidArgument() throws {
    let json = #"{"error":{"code":400,"message":"Bad","status":"INVALID_ARGUMENT"}}"#
    let decoded = try JSONDecoder().decode(GoogleSheetErrorResponse.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.error.status, .invalidArgument)
  }

  func test_decoding_unknownStatus_throws() {
    let json = #"{"error":{"code":418,"message":"Tea","status":"IM_A_TEAPOT"}}"#
    XCTAssertThrowsError(try JSONDecoder().decode(GoogleSheetErrorResponse.self, from: Data(json.utf8)))
  }

  func test_status_descriptions_areNonEmpty() {
    XCTAssertFalse(GoogleSheetErrorResponse.Status.permissionDenied.description.isEmpty)
    XCTAssertFalse(GoogleSheetErrorResponse.Status.notFound.description.isEmpty)
    XCTAssertFalse(GoogleSheetErrorResponse.Status.invalidArgument.description.isEmpty)
    XCTAssertTrue(GoogleSheetErrorResponse.Status.permissionDenied.description.contains("sharing"))
    XCTAssertTrue(GoogleSheetErrorResponse.Status.notFound.description.contains("couldn't be found"))
    XCTAssertTrue(GoogleSheetErrorResponse.Status.invalidArgument.description.contains("inputs"))
  }
}
