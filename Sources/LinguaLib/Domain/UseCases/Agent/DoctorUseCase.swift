import Foundation

public struct DoctorCheck: Encodable {
  public let name: String
  public let ok: Bool
  public let detail: String
}

public struct DoctorReport: Encodable {
  public let ok: Bool
  public let checks: [DoctorCheck]

  public init(checks: [DoctorCheck]) {
    self.checks = checks
    self.ok = checks.allSatisfy(\.ok)
  }
}

public protocol RunningDoctor {
  func run() async throws -> DoctorReport
}

public struct DoctorUseCase: RunningDoctor {
  private let config: Config.Localization
  private let sheetDataLoader: SheetDataLoader

  init(config: Config.Localization, sheetDataLoader: SheetDataLoader) {
    self.config = config
    self.sheetDataLoader = sheetDataLoader
  }

  public func run() async throws -> DoctorReport {
    var checks: [DoctorCheck] = []

    // 1. API key configured
    let apiKeyOK = !config.apiKey.isEmpty && !config.apiKey.contains("<")
    checks.append(.init(
      name: "config.apiKey",
      ok: apiKeyOK,
      detail: apiKeyOK ? "OK" : (config.apiKey.isEmpty ? "Missing apiKey" : "apiKey is still a placeholder ('\(config.apiKey)') — replace it with the real value")
    ))

    // 2. Sheet ID configured
    let sheetIdOK = !config.sheetId.isEmpty && !config.sheetId.contains("<")
    checks.append(.init(
      name: "config.sheetId",
      ok: sheetIdOK,
      detail: sheetIdOK ? "OK" : (config.sheetId.isEmpty ? "Missing sheetId" : "sheetId is still a placeholder ('\(config.sheetId)') — replace it with the real value")
    ))

    // 3. Output directory writable
    let outputDir = (config.outputDirectory as NSString).expandingTildeInPath
    let writable = FileManager.default.isWritableFile(atPath: outputDir)
      || (try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)) != nil
    checks.append(.init(
      name: "outputDirectory.writable",
      ok: writable,
      detail: writable ? outputDir : "Cannot write to \(outputDir)"
    ))

    // 4. Service account key (optional, but report if configured)
    if let saPath = config.serviceAccountKeyPath {
      do {
        _ = try ServiceAccountKey.load(fromPath: saPath)
        checks.append(.init(name: "serviceAccount.load", ok: true, detail: saPath))
      } catch {
        checks.append(.init(
          name: "serviceAccount.load",
          ok: false,
          detail: "Could not load service account JSON at \(saPath): \(error.localizedDescription)"
        ))
      }
    } else {
      checks.append(.init(
        name: "serviceAccount.load",
        ok: false,
        detail: "serviceAccountKeyPath not set — `lingua add` and `lingua update` will not work."
      ))
    }

    // 5. Sheet reachable + tab alignment
    do {
      let sheets = try await sheetDataLoader.loadSheets()
      if sheets.isEmpty {
        checks.append(.init(name: "sheet.reachable", ok: false, detail: "No tabs found in spreadsheet."))
      } else {
        checks.append(.init(name: "sheet.reachable", ok: true, detail: "\(sheets.count) language tabs"))

        guard let canonical = CanonicalSheetSelector.pick(from: sheets, preferred: config.defaultWriteSheet) else {
          checks.append(.init(name: "sheet.canonical", ok: false, detail: "No canonical tab"))
          return DoctorReport(checks: checks)
        }
        checks.append(.init(name: "sheet.canonical", ok: true, detail: canonical.language))

        let canonicalKeys = canonical.entries.map { "\($0.section)::\($0.key)" }
        var misaligned: [String] = []
        for sheet in sheets where sheet.language != canonical.language {
          let theseKeys = sheet.entries.map { "\($0.section)::\($0.key)" }
          if theseKeys != canonicalKeys {
            misaligned.append(sheet.language)
          }
        }
        checks.append(.init(
          name: "tabs.aligned",
          ok: misaligned.isEmpty,
          detail: misaligned.isEmpty ? "All tabs aligned" : "Misaligned tabs: \(misaligned.joined(separator: ", "))"
        ))
      }
    } catch {
      checks.append(.init(
        name: "sheet.reachable",
        ok: false,
        detail: "Could not fetch sheet: \(error.localizedDescription)"
      ))
    }

    return DoctorReport(checks: checks)
  }
}
