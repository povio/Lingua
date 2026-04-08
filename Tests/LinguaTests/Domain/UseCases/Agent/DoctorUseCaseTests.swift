import XCTest
@testable import LinguaLib

final class DoctorUseCaseTests: XCTestCase {

  private func makeConfig(
    apiKey: String = "real-api-key",
    sheetId: String = "real-sheet-id",
    outputDirectory: String? = nil,
    serviceAccountKeyPath: String? = nil,
    defaultWriteSheet: String? = nil
  ) -> Config.Localization {
    let dir = outputDirectory ?? NSTemporaryDirectory().appending("DoctorUseCaseTests-\(UUID().uuidString)")
    return Config.Localization(
      apiKey: apiKey,
      sheetId: sheetId,
      outputDirectory: dir,
      localizedSwiftCode: nil,
      serviceAccountKeyPath: serviceAccountKeyPath,
      defaultWriteSheet: defaultWriteSheet
    )
  }

  func test_run_reportsAllChecksOK_whenSheetReachableAndAligned() async throws {
    let sheets = [
      LocalizationSheet(language: "en_US_English", entries: [
        LocalizationEntry(section: "welcome", key: "title", translations: ["other": "Hi"], sheetRow: 2)
      ]),
      LocalizationSheet(language: "de_DE_German", entries: [
        LocalizationEntry(section: "welcome", key: "title", translations: ["other": "Hallo"], sheetRow: 2)
      ])
    ]
    let sut = DoctorUseCase(
      config: makeConfig(),
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets))
    )

    let report = try await sut.run()

    XCTAssertTrue(report.checks.contains(where: { $0.name == "config.apiKey" && $0.ok }))
    XCTAssertTrue(report.checks.contains(where: { $0.name == "config.sheetId" && $0.ok }))
    XCTAssertTrue(report.checks.contains(where: { $0.name == "outputDirectory.writable" && $0.ok }))
    XCTAssertTrue(report.checks.contains(where: { $0.name == "sheet.reachable" && $0.ok }))
    XCTAssertTrue(report.checks.contains(where: { $0.name == "sheet.canonical" && $0.ok }))
    XCTAssertTrue(report.checks.contains(where: { $0.name == "tabs.aligned" && $0.ok }))
  }

  func test_run_flagsPlaceholderApiKeyAndSheetId() async throws {
    let sut = DoctorUseCase(
      config: makeConfig(apiKey: "<your-api-key>", sheetId: "<sheet-id>"),
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success([]))
    )

    let report = try await sut.run()

    XCTAssertFalse(report.ok)
    XCTAssertTrue(report.checks.contains(where: { $0.name == "config.apiKey" && !$0.ok }))
    XCTAssertTrue(report.checks.contains(where: { $0.name == "config.sheetId" && !$0.ok }))
  }

  func test_run_flagsEmptyApiKeyAndSheetId() async throws {
    let sut = DoctorUseCase(
      config: makeConfig(apiKey: "", sheetId: ""),
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success([]))
    )

    let report = try await sut.run()

    XCTAssertFalse(report.ok)
    let api = report.checks.first { $0.name == "config.apiKey" }
    XCTAssertEqual(api?.ok, false)
    XCTAssertTrue(api?.detail.contains("Missing") ?? false)
  }

  func test_run_reportsMissingServiceAccountWhenNotConfigured() async throws {
    let sut = DoctorUseCase(
      config: makeConfig(serviceAccountKeyPath: nil),
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success([]))
    )

    let report = try await sut.run()

    let sa = report.checks.first { $0.name == "serviceAccount.load" }
    XCTAssertEqual(sa?.ok, false)
    XCTAssertTrue(sa?.detail.contains("not set") ?? false)
  }

  func test_run_reportsBrokenServiceAccountWhenPathInvalid() async throws {
    let sut = DoctorUseCase(
      config: makeConfig(serviceAccountKeyPath: "/nonexistent/path/key.json"),
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success([]))
    )

    let report = try await sut.run()

    let sa = report.checks.first { $0.name == "serviceAccount.load" }
    XCTAssertEqual(sa?.ok, false)
  }

  func test_run_reportsSheetUnreachable_whenLoaderFails() async throws {
    struct Boom: Error, LocalizedError { var errorDescription: String? { "boom" } }
    let sut = DoctorUseCase(
      config: makeConfig(),
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .failure(Boom()))
    )

    let report = try await sut.run()

    let reachable = report.checks.first { $0.name == "sheet.reachable" }
    XCTAssertEqual(reachable?.ok, false)
    XCTAssertTrue(reachable?.detail.contains("boom") ?? false)
  }

  func test_run_reportsEmptySheets_whenLoaderReturnsNone() async throws {
    let sut = DoctorUseCase(
      config: makeConfig(),
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success([]))
    )

    let report = try await sut.run()

    let reachable = report.checks.first { $0.name == "sheet.reachable" }
    XCTAssertEqual(reachable?.ok, false)
    XCTAssertTrue(reachable?.detail.contains("No tabs") ?? false)
  }

  func test_run_reportsMisalignedTabs_whenKeysDiffer() async throws {
    let sheets = [
      LocalizationSheet(language: "en_US_English", entries: [
        LocalizationEntry(section: "welcome", key: "title", translations: ["other": "Hi"], sheetRow: 2)
      ]),
      LocalizationSheet(language: "de_DE_German", entries: [
        LocalizationEntry(section: "welcome", key: "different_key", translations: ["other": "Hallo"], sheetRow: 2)
      ])
    ]
    let sut = DoctorUseCase(
      config: makeConfig(),
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets))
    )

    let report = try await sut.run()

    let aligned = report.checks.first { $0.name == "tabs.aligned" }
    XCTAssertEqual(aligned?.ok, false)
    XCTAssertTrue(aligned?.detail.contains("de_DE_German") ?? false)
  }
}
