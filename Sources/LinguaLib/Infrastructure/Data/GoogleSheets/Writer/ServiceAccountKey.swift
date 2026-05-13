import Foundation

struct ServiceAccountKey: Decodable {
  let type: String
  let projectId: String?
  let privateKeyId: String?
  let privateKey: String
  let clientEmail: String
  let tokenUri: String

  enum CodingKeys: String, CodingKey {
    case type
    case projectId = "project_id"
    case privateKeyId = "private_key_id"
    case privateKey = "private_key"
    case clientEmail = "client_email"
    case tokenUri = "token_uri"
  }

  static func load(fromPath path: String) throws -> ServiceAccountKey {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(ServiceAccountKey.self, from: data)
  }
}
