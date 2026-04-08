import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Public-ish protocol used by the agent use cases. The agent layer never speaks HTTP directly.
protocol GoogleSheetsWriting {
  /// Insert a single blank row at `oneBasedRowIndex` in the given tab, then write `cells` into it.
  /// `oneBasedRowIndex` matches the row number you'd see in the Google Sheets UI.
  func insertRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws

  /// Update an existing row's cells in-place. `oneBasedRowIndex` is the row number in the UI.
  func updateRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws

  /// Append a row at the bottom of the sheet. Kept for completeness; section-aware code paths
  /// should prefer `updateRow` at a known row index for deterministic behavior.
  func appendRow(sheetTab: String, cells: [String]) async throws

  /// Update one specific cell. `column` is 1-based (A=1).
  func updateCell(sheetTab: String, oneBasedRow: Int, oneBasedColumn: Int, value: String) async throws

  /// Delete a single row from the given tab. `oneBasedRowIndex` matches the row number you'd
  /// see in the Google Sheets UI.
  func deleteRow(sheetTab: String, oneBasedRowIndex: Int) async throws
}

final class GoogleSheetsWriter: GoogleSheetsWriting {
  private let sheetId: String
  private let tokenProvider: AccessTokenProviding
  private let urlSession: URLSession
  private var sheetGidCache: [String: Int] = [:]

  init(sheetId: String, tokenProvider: AccessTokenProviding, urlSession: URLSession = .shared) {
    self.sheetId = sheetId
    self.tokenProvider = tokenProvider
    self.urlSession = urlSession
  }

  func insertRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {
    let gid = try await sheetGid(forTab: sheetTab)
    // Google's API uses 0-based indices and a half-open range.
    let startIndex = oneBasedRowIndex - 1
    let body: [String: Any] = [
      "requests": [
        [
          "insertDimension": [
            "range": [
              "sheetId": gid,
              "dimension": "ROWS",
              "startIndex": startIndex,
              "endIndex": startIndex + 1
            ],
            "inheritFromBefore": startIndex > 0
          ]
        ]
      ]
    ]
    try await batchUpdate(body: body)
    try await writeValues(tab: sheetTab, oneBasedRow: oneBasedRowIndex, cells: cells)
  }

  func updateRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {
    try await writeValues(tab: sheetTab, oneBasedRow: oneBasedRowIndex, cells: cells)
  }

  func appendRow(sheetTab: String, cells: [String]) async throws {
    let token = try await tokenProvider.token()
    let escapedTab = encodeTab(sheetTab)
    let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(sheetId)/values/\(escapedTab)!A:Z:append?valueInputOption=RAW&insertDataOption=INSERT_ROWS"
    guard let url = URL(string: urlString) else {
      throw AgentError(code: "invalid_url", message: "Could not build append URL.")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = ["values": [cells]]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    try await send(request)
  }

  func updateCell(sheetTab: String, oneBasedRow: Int, oneBasedColumn: Int, value: String) async throws {
    let column = Self.columnLetters(forIndex: oneBasedColumn)
    let range = "\(sheetTab)!\(column)\(oneBasedRow)"
    try await writeValuesAtRange(range: range, values: [[value]])
  }

  func deleteRow(sheetTab: String, oneBasedRowIndex: Int) async throws {
    let gid = try await sheetGid(forTab: sheetTab)
    let startIndex = oneBasedRowIndex - 1
    let body: [String: Any] = [
      "requests": [
        [
          "deleteDimension": [
            "range": [
              "sheetId": gid,
              "dimension": "ROWS",
              "startIndex": startIndex,
              "endIndex": startIndex + 1
            ]
          ]
        ]
      ]
    ]
    try await batchUpdate(body: body)
  }

  // MARK: - Helpers

  private func writeValues(tab: String, oneBasedRow: Int, cells: [String]) async throws {
    let endColumn = Self.columnLetters(forIndex: max(cells.count, 1))
    let range = "\(tab)!A\(oneBasedRow):\(endColumn)\(oneBasedRow)"
    try await writeValuesAtRange(range: range, values: [cells])
  }

  private func writeValuesAtRange(range: String, values: [[String]]) async throws {
    let token = try await tokenProvider.token()
    let escapedRange = encodeTab(range)
    let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(sheetId)/values/\(escapedRange)?valueInputOption=RAW"
    guard let url = URL(string: urlString) else {
      throw AgentError(code: "invalid_url", message: "Could not build values.update URL.")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = ["range": range, "majorDimension": "ROWS", "values": values]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    try await send(request)
  }

  private func batchUpdate(body: [String: Any]) async throws {
    let token = try await tokenProvider.token()
    let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(sheetId):batchUpdate"
    guard let url = URL(string: urlString) else {
      throw AgentError(code: "invalid_url", message: "Could not build batchUpdate URL.")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    try await send(request)
  }

  private func send(_ request: URLRequest) async throws {
    let (data, response) = try await urlSession.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
      throw AgentError(
        code: "google_sheets_write_failed",
        message: "Google Sheets API write failed: \(bodyText)"
      )
    }
  }

  /// Look up the numeric `sheetId` (gid) of a tab by name. Cached after the first call.
  private func sheetGid(forTab tab: String) async throws -> Int {
    if let cached = sheetGidCache[tab] { return cached }
    let token = try await tokenProvider.token()
    let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(sheetId)?fields=sheets.properties"
    guard let url = URL(string: urlString) else {
      throw AgentError(code: "invalid_url", message: "Could not build metadata URL.")
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await urlSession.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
      throw AgentError(code: "metadata_fetch_failed", message: bodyText)
    }
    struct Meta: Decodable {
      struct Sheet: Decodable {
        struct Props: Decodable { let sheetId: Int; let title: String }
        let properties: Props
      }
      let sheets: [Sheet]
    }
    let meta = try JSONDecoder().decode(Meta.self, from: data)
    for sheet in meta.sheets {
      sheetGidCache[sheet.properties.title] = sheet.properties.sheetId
    }
    guard let gid = sheetGidCache[tab] else {
      throw AgentError(
        code: "sheet_tab_not_found",
        message: "Could not find a tab named '\(tab)' in the spreadsheet."
      )
    }
    return gid
  }

  private func encodeTab(_ tab: String) -> String {
    tab.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tab
  }

  /// 1 → "A", 26 → "Z", 27 → "AA"
  static func columnLetters(forIndex index: Int) -> String {
    var n = max(index, 1)
    var result = ""
    while n > 0 {
      let r = (n - 1) % 26
      result = String(UnicodeScalar(65 + r)!) + result
      n = (n - 1) / 26
    }
    return result
  }
}
