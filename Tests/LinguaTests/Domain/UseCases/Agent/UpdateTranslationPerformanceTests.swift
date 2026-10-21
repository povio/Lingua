import Foundation
import XCTest
@testable import LinguaLib

final class UpdateTranslationPerformanceTests: XCTestCase {
  // Run with: LINGUA_RUN_BENCHMARKS=1 swift test -c release --filter UpdateTranslationPerformanceTests
  func test_updateBatch_withTenThousandEntries() async throws {
    guard ProcessInfo.processInfo.environment["LINGUA_RUN_BENCHMARKS"] == "1" else {
      throw XCTSkip("Set LINGUA_RUN_BENCHMARKS=1 to run the local batch benchmark.")
    }

    let rowCount = 10_000
    let sheets = ["en_US_English", "de_DE_German"].enumerated().map { tab, language in
      LocalizationSheet(language: language, entries: (0..<rowCount).map { index in
        LocalizationEntry(
          section: "General",
          key: "key_\(index)",
          translations: ["one": "Value \(index)"],
          sheetRow: index + 2 + index / (tab == 0 ? 50 : 100)
        )
      })
    }

    for batchSize in [1, 100, 1_000, 10_000] {
      // Spread updates across the sheet, including its last entry, for every batch size.
      let offsets = (0..<batchSize).map { ($0 + 1) * rowCount / batchSize - 1 }
      let updates = offsets.map { index in
        TranslationUpdate(section: "General", key: "key_\(index)", assignments: [
          ValueAssignment(language: "de", form: nil, text: "Updated \(index)")
        ])
      }
      var milliseconds: [Double] = []

      // One warmup followed by three measured runs. Fixture setup and assertions aren't timed.
      for run in 0..<4 {
        let writer = BenchmarkWriter()
        let sut = UpdateTranslationUseCase(
          sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
          writer: writer,
          preferredSheet: "en_US_English"
        )
        let start = DispatchTime.now().uptimeNanoseconds
        let result = try await sut.updateBatch(updates)
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        if run > 0 { milliseconds.append(elapsed) }

        XCTAssertEqual(result.totalUpdated, batchSize)
        XCTAssertTrue(result.notFound.isEmpty)
        XCTAssertEqual(writer.batchCalls, 1)
        XCTAssertEqual(writer.edits.count, batchSize)
        XCTAssertEqual(result.items.count, batchSize)
        guard writer.edits.count == batchSize, result.items.count == batchSize else { return }
        for (position, offset) in offsets.enumerated() {
          XCTAssertEqual(result.items[position].rowIndex, sheets[0].entries[offset].sheetRow)
          XCTAssertEqual(writer.edits[position], SheetBatchEdit(
            sheetTab: sheets[1].language,
            startRow: sheets[1].entries[offset].sheetRow,
            startColumn: 4,
            rows: [["Updated \(offset)"]],
            mode: .writeOnly
          ))
        }
      }

      let samples = milliseconds.map { String(format: "%.2f", $0) }.joined(separator: ", ")
      print("Batch benchmark: \(rowCount) entries/tab, 2 tabs, \(batchSize) updates; "
        + "median \(String(format: "%.2f", milliseconds.sorted()[1])) ms; samples [\(samples)] ms")
    }
  }
}

private final class BenchmarkWriter: GoogleSheetsWriting {
  private(set) var edits: [SheetBatchEdit] = []
  private(set) var batchCalls = 0

  func applyBatchEdits(_ edits: [SheetBatchEdit]) async throws {
    batchCalls += 1
    self.edits = edits
  }

  func insertRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {
    XCTFail("Unexpected insertRow")
  }
  func updateRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {
    XCTFail("Unexpected updateRow")
  }
  func appendRow(sheetTab: String, cells: [String]) async throws {
    XCTFail("Unexpected appendRow")
  }
  func updateCell(sheetTab: String, oneBasedRow: Int, oneBasedColumn: Int, value: String) async throws {
    XCTFail("Unexpected updateCell")
  }
  func deleteRow(sheetTab: String, oneBasedRowIndex: Int) async throws {
    XCTFail("Unexpected deleteRow")
  }
}
