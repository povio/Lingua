import Foundation

/// Stable JSON envelope used by all agent-facing subcommands.
///
/// Success: `{"ok": true, "data": ...}`
/// Failure: `{"ok": false, "error": {"code": "...", "message": "...", "details": ...}}`
public struct AgentJSONOutput {
  public static let shared = AgentJSONOutput()

  private let encoder: JSONEncoder

  public init() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    self.encoder = encoder
  }

  public func emitSuccess<T: Encodable>(_ data: T) throws {
    let envelope = SuccessEnvelope(ok: true, data: data)
    let bytes = try encoder.encode(envelope)
    if let s = String(data: bytes, encoding: .utf8) {
      print(s)
    }
  }

  public func emitFailure(code: String, message: String, details: [String: String]? = nil) {
    let envelope = FailureEnvelope(
      ok: false,
      error: .init(code: code, message: message, details: details)
    )
    if let bytes = try? encoder.encode(envelope), let s = String(data: bytes, encoding: .utf8) {
      FileHandle.standardError.write(Data((s + "\n").utf8))
    } else {
      FileHandle.standardError.write(Data("{\"ok\":false,\"error\":{\"code\":\"\(code)\",\"message\":\"\(message)\"}}\n".utf8))
    }
  }
}

private struct SuccessEnvelope<T: Encodable>: Encodable {
  let ok: Bool
  let data: T
}

private struct FailureEnvelope: Encodable {
  let ok: Bool
  let error: ErrorBody

  struct ErrorBody: Encodable {
    let code: String
    let message: String
    let details: [String: String]?
  }
}

/// Domain error type that subcommands raise to map cleanly to the JSON envelope.
public struct AgentError: Error {
  public let code: String
  public let message: String
  public let details: [String: String]?

  public init(code: String, message: String, details: [String: String]? = nil) {
    self.code = code
    self.message = message
    self.details = details
  }
}
