import Foundation

final class CustomJSONEncoder: JSONEncoder, @unchecked Sendable {
  override func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let originalData = try encoder.encode(value)
    
    guard let originalString = String(data: originalData, encoding: .utf8) else {
      throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unable to encode value to JSON"))
    }
    
    let unescapedString = originalString.replacingOccurrences(of: "\\/", with: "/")
    guard let unescapedData = unescapedString.data(using: .utf8) else {
      throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unable to encode value to JSON"))
    }
    
    return unescapedData
  }
}
