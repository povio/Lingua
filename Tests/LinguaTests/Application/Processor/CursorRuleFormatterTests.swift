import XCTest
@testable import Lingua

final class CursorRuleFormatterTests: XCTestCase {

  func test_mdc_emitsCursorFrontmatterAndPreservesBody() throws {
    let skill = try XCTUnwrap(BundledSkills.all.first { $0.name == "lingua-add-translation" })
    let mdc = CursorRuleFormatter.mdc(for: skill)

    XCTAssertTrue(mdc.hasPrefix("---\n"))
    XCTAssertTrue(mdc.contains("description: \(skill.cursorDescription)"))
    XCTAssertTrue(mdc.contains("globs: [\"**/*.swift\""))
    XCTAssertTrue(mdc.contains("alwaysApply: false"))
    // Body from the original SKILL.md should still be present.
    XCTAssertTrue(mdc.contains("# Adding a new translation with Lingua"))
    // Original Claude Code frontmatter must be stripped.
    XCTAssertFalse(mdc.contains("name: lingua-add-translation"))
  }

  func test_mdc_omitsGlobsLineWhenSkillHasNoGlobs() throws {
    let skill = try XCTUnwrap(BundledSkills.all.first { $0.name == "lingua-doctor" })
    XCTAssertTrue(skill.cursorGlobs.isEmpty, "Precondition: doctor skill has no globs")

    let mdc = CursorRuleFormatter.mdc(for: skill)
    XCTAssertFalse(mdc.contains("globs:"), "Cursor rule should omit globs entirely when skill has none")
    XCTAssertTrue(mdc.contains("alwaysApply: false"))
    XCTAssertTrue(mdc.contains("# Diagnosing Lingua configuration"))
  }

  func test_extractBody_stripsLeadingFrontmatter() {
    let input = """
    ---
    name: foo
    description: bar
    ---

    # Heading

    body line
    """
    let body = CursorRuleFormatter.extractBody(from: input)
    XCTAssertEqual(body, "# Heading\n\nbody line")
  }

  func test_extractBody_returnsInputWhenNoFrontmatter() {
    let input = "no frontmatter here"
    XCTAssertEqual(CursorRuleFormatter.extractBody(from: input), input)
  }

  func test_allBundledSkills_renderToValidMdc() {
    for skill in BundledSkills.all {
      let mdc = CursorRuleFormatter.mdc(for: skill)
      XCTAssertTrue(mdc.hasPrefix("---\n"), "\(skill.name) missing frontmatter opener")
      XCTAssertTrue(mdc.contains("\n---\n\n"), "\(skill.name) missing frontmatter closer")
      XCTAssertTrue(mdc.contains("alwaysApply: false"), "\(skill.name) missing alwaysApply")
      XCTAssertFalse(mdc.contains("\nname: \(skill.name)"), "\(skill.name) leaked Claude frontmatter")
    }
  }
}
