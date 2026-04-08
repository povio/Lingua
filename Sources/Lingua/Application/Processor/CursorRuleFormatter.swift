import Foundation

/// Converts a `BundledSkills.Skill` into a Cursor `.mdc` rule file body.
///
/// The Claude Code skill format and the Cursor rule format share the same markdown body but
/// use different YAML frontmatter:
///
///     Claude Code SKILL.md            Cursor .mdc
///     ---                             ---
///     name: lingua-add-translation    description: Add a new localized string ...
///     description: Add a new ...      globs: ["**/*.swift", ...]
///     ---                             alwaysApply: false
///                                     ---
///
/// We strip the original frontmatter, keep the markdown body verbatim, and re-emit
/// Cursor-flavored frontmatter built from the per-skill metadata in `BundledSkills.Skill`.
enum CursorRuleFormatter {
  /// Render `skill` as a Cursor `.mdc` file.
  static func mdc(for skill: BundledSkills.Skill) -> String {
    let body = extractBody(from: skill.contents)
    var frontmatter = "---\n"
    frontmatter += "description: \(escapeForYAML(skill.cursorDescription))\n"
    if !skill.cursorGlobs.isEmpty {
      frontmatter += "globs: \(formatGlobs(skill.cursorGlobs))\n"
    }
    frontmatter += "alwaysApply: false\n"
    frontmatter += "---\n\n"
    return frontmatter + body
  }

  /// Strips the leading `---\n…\n---\n` block from a Claude Code SKILL.md and returns the
  /// markdown body. If the input doesn't begin with frontmatter (defensive — shouldn't happen
  /// for our bundled skills), the whole input is returned as-is.
  static func extractBody(from contents: String) -> String {
    guard contents.hasPrefix("---") else { return contents }
    var lines = contents.components(separatedBy: "\n")
    // Drop the opening "---"
    lines.removeFirst()
    // Drop everything up to and including the closing "---"
    guard let closingIndex = lines.firstIndex(of: "---") else { return contents }
    lines.removeSubrange(0...closingIndex)
    // Drop one leading blank line if present so the body starts cleanly under the new
    // frontmatter (we add our own blank line after the new frontmatter).
    if lines.first == "" { lines.removeFirst() }
    return lines.joined(separator: "\n")
  }

  /// Emits a YAML inline list of glob strings, e.g. `["**/*.swift", "**/*.kt"]`. Cursor
  /// accepts both inline and block list syntax; inline keeps the file compact.
  private static func formatGlobs(_ globs: [String]) -> String {
    let quoted = globs.map { "\"\($0)\"" }
    return "[\(quoted.joined(separator: ", "))]"
  }

  /// Minimal YAML string escaping. Our descriptions never contain control characters or
  /// quotes, so we just guard against newlines (which would terminate the YAML value).
  private static func escapeForYAML(_ value: String) -> String {
    value.replacingOccurrences(of: "\n", with: " ")
  }
}
