import XCTest
import LinguaLib
@testable import Lingua

final class BatchFileLoaderTests: XCTestCase {

  func test_loadAddBatch_parsesPlainAndPluralValues() throws {
    let url = writeTempFile(contents: """
    [
      {"section": "Settings", "key": "title", "values": {"en": "Settings", "de": "Einstellungen"}},
      {"section": "Cart", "key": "item_count", "values": {
        "en": {"one": "1 item", "other": "%d items"},
        "de": {"one": "1 Artikel", "other": "%d Artikel"}
      }}
    ]
    """)
    defer { try? FileManager.default.removeItem(at: url) }

    let batch = try BatchFileLoader.loadAddBatch(path: url.path, allowNewSections: true, dryRun: false)
    XCTAssertEqual(batch.items.count, 2)
    XCTAssertTrue(batch.allowNewSections)
    XCTAssertFalse(batch.dryRun)

    let plain = batch.items[0]
    XCTAssertEqual(plain.section, "Settings")
    XCTAssertEqual(plain.key, "title")
    XCTAssertEqual(Set(plain.assignments.map(\.language)), ["en", "de"])
    XCTAssertTrue(plain.assignments.allSatisfy { $0.form == nil })

    let plural = batch.items[1]
    let englishForms = plural.assignments.filter { $0.language == "en" }.compactMap { $0.form }
    XCTAssertEqual(Set(englishForms), ["one", "other"])
    let englishOther = plural.assignments.first { $0.language == "en" && $0.form == "other" }
    XCTAssertEqual(englishOther?.text, "%d items")
  }

  func test_loadAddBatch_invalidJson_throwsAgentError() {
    let url = writeTempFile(contents: "not actually json")
    defer { try? FileManager.default.removeItem(at: url) }

    do {
      _ = try BatchFileLoader.loadAddBatch(path: url.path, allowNewSections: false, dryRun: false)
      XCTFail("expected batch_file_invalid")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "batch_file_invalid")
    } catch {
      XCTFail("expected AgentError, got \(error)")
    }
  }

  func test_loadAddBatch_missingFile_throwsAgentError() {
    do {
      _ = try BatchFileLoader.loadAddBatch(path: "/tmp/does-not-exist-\(UUID().uuidString).json", allowNewSections: false, dryRun: false)
      XCTFail("expected batch_file_unreadable")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "batch_file_unreadable")
    } catch {
      XCTFail("expected AgentError, got \(error)")
    }
  }

  func test_loadUpdateBatch_parsesIntoTranslationUpdates() throws {
    let url = writeTempFile(contents: """
    [
      {"section": "Settings", "key": "title", "values": {"en": "Preferences"}}
    ]
    """)
    defer { try? FileManager.default.removeItem(at: url) }

    let updates = try BatchFileLoader.loadUpdateBatch(path: url.path)
    XCTAssertEqual(updates.count, 1)
    XCTAssertEqual(updates[0].section, "Settings")
    XCTAssertEqual(updates[0].key, "title")
    XCTAssertEqual(updates[0].assignments.first?.text, "Preferences")
  }

  // MARK: - Helpers

  private func writeTempFile(contents: String) -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
    try? contents.data(using: .utf8)?.write(to: url)
    return url
  }
}
