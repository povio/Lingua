import Foundation

public struct DeletedTranslation: Encodable {
  public let section: String
  public let key: String
  public let rowsDeleted: [DeletedRow]
}

public struct DeletedRow: Encodable {
  public let tab: String
  public let row: Int
}

public protocol DeletingTranslation {
  func delete(section: String, key: String) async throws -> DeletedTranslation
}

/// Removes a `(section, key)` row from every language tab where it exists.
///
/// Unlike `add` / `update`, this use case **does not require tabs to be aligned**. It searches
/// each tab independently. This makes it the right escape hatch for recovering from a failed
/// `add` that left a row in some tabs but not others.
public struct DeleteTranslationUseCase: DeletingTranslation {
  private let sheetDataLoader: SheetDataLoader
  private let writer: GoogleSheetsWriting

  init(sheetDataLoader: SheetDataLoader, writer: GoogleSheetsWriting) {
    self.sheetDataLoader = sheetDataLoader
    self.writer = writer
  }

  public func delete(section: String, key: String) async throws -> DeletedTranslation {
    let sheets = try await sheetDataLoader.loadSheets()
    if sheets.isEmpty {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }

    var deletions: [DeletedRow] = []

    // Delete from highest row index to lowest within each tab so earlier deletions don't shift
    // later target rows. Different tabs are independent. Uses each entry's recorded sheet row
    // so blank separator rows in the sheet don't throw off the math.
    for sheet in sheets {
      let matchingRows = sheet.entries
        .filter { $0.section == section && $0.key == key }
        .map(\.sheetRow)
        .sorted(by: >)

      for row in matchingRows {
        try await writer.deleteRow(sheetTab: sheet.language, oneBasedRowIndex: row)
        deletions.append(DeletedRow(tab: sheet.language, row: row))
      }
    }

    if deletions.isEmpty {
      throw AgentError(
        code: "not_found",
        message: "No row found for section '\(section)' / key '\(key)' in any language tab.",
        details: ["section": section, "key": key]
      )
    }

    return DeletedTranslation(section: section, key: key, rowsDeleted: deletions)
  }
}
