import XCTest
@testable import LinguaLib

final class AgentJSONOutputTests: XCTestCase {

  func test_emitSuccess_writesEnvelopeToStdout() throws {
    struct Payload: Encodable { let value: Int }
    let sut = AgentJSONOutput()

    let captured = try captureStdout {
      try sut.emitSuccess(Payload(value: 42))
    }

    let json = try XCTUnwrap(parseJSON(captured))
    XCTAssertEqual(json["ok"] as? Bool, true)
    let data = try XCTUnwrap(json["data"] as? [String: Any])
    XCTAssertEqual(data["value"] as? Int, 42)
  }

  func test_emitFailure_writesEnvelopeToStderr() throws {
    let sut = AgentJSONOutput()

    let captured = captureStderr {
      sut.emitFailure(code: "boom", message: "something failed", details: ["k": "v"])
    }

    let json = try XCTUnwrap(parseJSON(captured))
    XCTAssertEqual(json["ok"] as? Bool, false)
    let err = try XCTUnwrap(json["error"] as? [String: Any])
    XCTAssertEqual(err["code"] as? String, "boom")
    XCTAssertEqual(err["message"] as? String, "something failed")
    let details = try XCTUnwrap(err["details"] as? [String: String])
    XCTAssertEqual(details["k"], "v")
  }

  func test_emitFailure_withoutDetails_omitsNothingButReturnsValidJSON() throws {
    let sut = AgentJSONOutput()

    let captured = captureStderr {
      sut.emitFailure(code: "x", message: "y")
    }

    let json = try XCTUnwrap(parseJSON(captured))
    XCTAssertEqual(json["ok"] as? Bool, false)
  }

  // MARK: - Helpers

  private func parseJSON(_ s: String) -> [String: Any]? {
    guard let data = s.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  private func captureStdout(_ block: () throws -> Void) rethrows -> String {
    try capture(fd: fileno(stdout), flush: { fflush(stdout) }, block: block)
  }

  private func captureStderr(_ block: () -> Void) -> String {
    capture(fd: fileno(stderr), flush: { fflush(stderr) }, block: block)
  }

  /// Redirects a single file descriptor (stdout/stderr) to a pipe, runs `block`, then restores
  /// the original fd before reading from the pipe.
  ///
  /// Critical ordering: `dup2(pipeWrite, targetFd)` makes `targetFd` an *additional* reference
  /// to the pipe's write end. Closing only the Pipe's `fileHandleForWriting` is not enough — the
  /// duped fd still keeps the pipe writable and `readToEnd()` will block forever waiting for EOF.
  /// We must restore the original fd (which closes the duped reference) AND close the Pipe's own
  /// write handle before reading.
  private func capture(fd targetFd: Int32, flush: () -> Void, block: () throws -> Void) rethrows -> String {
    flush()
    let savedFd = dup(targetFd)
    let pipe = Pipe()
    dup2(pipe.fileHandleForWriting.fileDescriptor, targetFd)

    try block()
    flush()

    // Restore first — this closes the duped reference inside `targetFd`.
    dup2(savedFd, targetFd)
    close(savedFd)
    // Then close the Pipe's own write handle so the reader sees EOF.
    try? pipe.fileHandleForWriting.close()

    let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
    try? pipe.fileHandleForReading.close()
    return String(data: data, encoding: .utf8) ?? ""
  }
}
