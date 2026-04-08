import XCTest
@testable import LinguaLib

final class AgentModuleFactoryTests: XCTestCase {
  func test_makeListSections_returnsListingSections() {
    let factory = AgentModuleFactory()
    let useCase = factory.makeListSections(config: makeConfig())
    XCTAssertNotNil(useCase as Any)
    XCTAssertTrue(useCase is ListSectionsUseCase)
  }

  func test_makeListTranslations_returnsListingTranslations() {
    let factory = AgentModuleFactory()
    let useCase = factory.makeListTranslations(config: makeConfig())
    XCTAssertTrue(useCase is ListTranslationsUseCase)
  }

  func test_makeFindTranslation_returnsFindingTranslations() {
    let factory = AgentModuleFactory()
    let useCase = factory.makeFindTranslation(config: makeConfig())
    XCTAssertTrue(useCase is FindTranslationUseCase)
  }

  func test_makeDoctor_returnsRunningDoctor() {
    let factory = AgentModuleFactory()
    let useCase = factory.makeDoctor(config: makeConfig())
    XCTAssertTrue(useCase is DoctorUseCase)
  }

  func test_makeAddTranslation_withoutServiceAccountPath_throwsMissingServiceAccount() {
    let factory = AgentModuleFactory()
    XCTAssertThrowsError(try factory.makeAddTranslation(config: makeConfig(serviceAccountKeyPath: nil))) { error in
      guard let agent = error as? AgentError else { return XCTFail("expected AgentError") }
      XCTAssertEqual(agent.code, "missing_service_account")
    }
  }

  func test_makeUpdateTranslation_withoutServiceAccountPath_throwsMissingServiceAccount() {
    let factory = AgentModuleFactory()
    XCTAssertThrowsError(try factory.makeUpdateTranslation(config: makeConfig(serviceAccountKeyPath: nil))) { error in
      guard let agent = error as? AgentError else { return XCTFail("expected AgentError") }
      XCTAssertEqual(agent.code, "missing_service_account")
    }
  }

  func test_makeDeleteTranslation_withoutServiceAccountPath_throwsMissingServiceAccount() {
    let factory = AgentModuleFactory()
    XCTAssertThrowsError(try factory.makeDeleteTranslation(config: makeConfig(serviceAccountKeyPath: nil))) { error in
      guard let agent = error as? AgentError else { return XCTFail("expected AgentError") }
      XCTAssertEqual(agent.code, "missing_service_account")
    }
  }

  func test_makeAddTranslation_withValidServiceAccountKey_returnsAddingTranslation() throws {
    let path = try writeFakeServiceAccountKey()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let factory = AgentModuleFactory()
    let useCase = try factory.makeAddTranslation(config: makeConfig(serviceAccountKeyPath: path))
    XCTAssertTrue(useCase is AddTranslationUseCase)
  }

  func test_makeUpdateTranslation_withValidServiceAccountKey_returnsUpdatingTranslation() throws {
    let path = try writeFakeServiceAccountKey()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let factory = AgentModuleFactory()
    let useCase = try factory.makeUpdateTranslation(config: makeConfig(serviceAccountKeyPath: path))
    XCTAssertTrue(useCase is UpdateTranslationUseCase)
  }

  func test_makeDeleteTranslation_withValidServiceAccountKey_returnsDeletingTranslation() throws {
    let path = try writeFakeServiceAccountKey()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let factory = AgentModuleFactory()
    let useCase = try factory.makeDeleteTranslation(config: makeConfig(serviceAccountKeyPath: path))
    XCTAssertTrue(useCase is DeleteTranslationUseCase)
  }
}

private extension AgentModuleFactoryTests {
  func makeConfig(serviceAccountKeyPath: String? = nil) -> Config.Localization {
    Config.Localization(
      apiKey: "test-api-key",
      sheetId: "test-sheet-id",
      outputDirectory: "/tmp/out",
      localizedSwiftCode: nil,
      allowedSections: nil,
      serviceAccountKeyPath: serviceAccountKeyPath,
      defaultWriteSheet: "main"
    )
  }

  func writeFakeServiceAccountKey() throws -> String {
    let pem = TestRSAKey.generatePEMPrivateKey()
    let escapedPem = pem.replacingOccurrences(of: "\n", with: "\\n")
    let json = """
    {
      "type": "service_account",
      "project_id": "test-project",
      "private_key_id": "test-key-id",
      "private_key": "\(escapedPem)",
      "client_email": "test@test.iam.gserviceaccount.com",
      "token_uri": "https://oauth2.googleapis.com/token"
    }
    """
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
    try json.write(to: url, atomically: true, encoding: .utf8)
    return url.path
  }
}
