import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One slice of work to apply to a single tab as part of a batched edit. `startRow` is always
/// expressed in the **original** 1-based row space of the sheet (the row number you would see
/// in the Google Sheets UI before any edit in this batch has executed). The writer is
/// responsible for translating that into the right index sequencing when multiple edits land
/// in the same tab.
struct SheetBatchEdit: Equatable {
  enum Mode: Equatable {
    /// Shift existing rows down by `rows.count` starting at `startRow`, then write `rows`.
    /// Used when growing an existing section.
    case insertRows
    /// Write `rows` over the existing cells starting at `(startRow, startColumn)`. No row
    /// insertion happens — useful for new sections appended past the last existing row, where
    /// the cells are already blank, AND for in-place updates of specific cells (where
    /// `startColumn` shifts the write window away from column A).
    case writeOnly
  }

  let sheetTab: String
  let startRow: Int
  /// 1-based column at which `rows[*]` begin. Defaults to column A — only `update --batch`
  /// uses anything other than 1 (to target the right plural-form column).
  let startColumn: Int
  let rows: [[String]]
  let mode: Mode

  init(sheetTab: String, startRow: Int, startColumn: Int = 1, rows: [[String]], mode: Mode) {
    self.sheetTab = sheetTab
    self.startRow = startRow
    self.startColumn = startColumn
    self.rows = rows
    self.mode = mode
  }
}

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

  /// Apply a list of edits across one or more tabs in a single Google Sheets `batchUpdate`
  /// HTTP call. The implementation sequences the edits so each `startRow` is interpreted in
  /// the original sheet's row space — callers can plan rows from a single pre-batch
  /// `loadSheets()` snapshot without worrying about row drift between operations.
  func applyBatchEdits(_ edits: [SheetBatchEdit]) async throws
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

  func applyBatchEdits(_ edits: [SheetBatchEdit]) async throws {
    if edits.isEmpty { return }

    // Resolve all tab gids in one metadata round trip (after the first call, the cache covers
    // every tab in the spreadsheet so subsequent lookups are free).
    for tab in Set(edits.map(\.sheetTab)) {
      _ = try await sheetGid(forTab: tab)
    }

    // Ordering rules so every edit's `startRow` stays valid in the original row space:
    //   1. All `writeOnly` edits (new sections at the bottom of the canonical sheet) execute
    //      first. They overwrite still-blank cells past the last existing row, so they don't
    //      perturb any row index above them.
    //   2. `insertRows` edits then execute in DESCENDING `startRow` order. Each insertion at a
    //      lower row shifts the rows below — but the higher-row insertions already completed
    //      against their original positions, and the now-written `writeOnly` rows naturally
    //      shift along with the rest of the sheet to their final destinations.
    //
    // Edits in different tabs are independent (different `sheetId`), so we don't need a
    // per-tab grouping — the global sort is sufficient as long as the relative order within a
    // tab is correct.
    let writeOnlys = edits.filter { $0.mode == .writeOnly }
    let inserts = edits.filter { $0.mode == .insertRows }
      .sorted { $0.startRow > $1.startRow }
    let ordered = writeOnlys + inserts

    var requests: [[String: Any]] = []
    for edit in ordered {
      guard let gid = sheetGidCache[edit.sheetTab] else {
        throw AgentError(
          code: "sheet_tab_not_found",
          message: "Could not find a tab named '\(edit.sheetTab)' in the spreadsheet."
        )
      }
      let startIndex = edit.startRow - 1
      let endIndex = startIndex + edit.rows.count

      if edit.mode == .insertRows {
        requests.append([
          "insertDimension": [
            "range": [
              "sheetId": gid,
              "dimension": "ROWS",
              "startIndex": startIndex,
              "endIndex": endIndex
            ],
            "inheritFromBefore": startIndex > 0
          ]
        ])
      }

      requests.append([
        "updateCells": [
          "rows": edit.rows.map { Self.rowDataPayload(cells: $0) },
          "fields": "userEnteredValue",
          "start": [
            "sheetId": gid,
            "rowIndex": startIndex,
            "columnIndex": edit.startColumn - 1
          ]
        ]
      ])
    }

    try await batchUpdate(body: ["requests": requests])
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

  /// Builds the `RowData` payload one row at a time for `updateCells` requests. Each cell is
  /// emitted as `userEnteredValue.stringValue` to match the existing `valueInputOption=RAW`
  /// semantics — formulas in the text are not interpreted, mirroring `values.update`.
  static func rowDataPayload(cells: [String]) -> [String: Any] {
    let values: [[String: Any]] = cells.map { cell in
      ["userEnteredValue": ["stringValue": cell]]
    }
    return ["values": values]
  }
}
