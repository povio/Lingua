import Foundation
import LinguaLib

enum HelpText {
  /// Resolves per-subcommand help text. Returns the top-level `usage` for unknown / help
  /// commands so `lingua --help` keeps working unchanged.
  static func help(for command: Command?) -> String {
    switch command {
    case .add: return addHelp
    case .update: return updateHelp
    case .find: return findHelp
    case .sections: return sectionsHelp
    case .list: return listHelp
    case .delete: return deleteHelp
    case .sync: return syncHelp
    case .doctor: return doctorHelp
    case .ai: return aiHelp
    default: return usage
    }
  }

  static let addHelp = """
  USAGE
    lingua add <config.json> --section <s> --key <k> --value <lang>[:form]=<text> [--value ...]
                             [--new-section] [--dry-run] [--sync ios|android|ios,android]
    lingua add <config.json> --batch <file.json>
                             [--new-section] [--dry-run] [--sync ios|android|ios,android]

  Insert one or more rows into the canonical Google Sheet, section-aware. Prefer --batch
  for ≥ 2 keys — one HTTP round trip instead of N.

  FLAGS
    --section <s>         Target section (must exist unless --new-section is also passed).
    --key <k>             Snake_case key for the new row.
    --value <l>[:f]=<t>   Per-language value. Form is one of zero/one/two/few/many/other.
                          Omit `:form` for non-plural strings (auto-picks the default column).
    --batch <file>        JSON array of {section, key, values} entries (see SCHEMA below).
    --new-section         Allow creating a section that doesn't exist yet.
    --dry-run             Plan the write without sending it.
    --sync <list>         After writing, regenerate platform files. Comma-separated list of
                          `ios`, `android`. Saves a separate `lingua sync` invocation.

  --batch JSON SCHEMA
    [
      {"section": "Settings", "key": "title",
       "values": {"en": "Settings", "de": "Einstellungen"}},
      {"section": "Cart", "key": "item_count",
       "values": {"en": {"one": "1 item",    "other": "%d items"},
                  "de": {"one": "1 Artikel", "other": "%d Artikel"}}}
    ]

  EXAMPLES
    lingua add ./config.json --section onboarding --key cta_start \\
      --value en="Get started" --value de="Loslegen" --sync ios

    lingua add ./config.json --batch /tmp/batch.json --new-section --sync ios,android
  """

  static let updateHelp = """
  USAGE
    lingua update <config.json> --section <s> --key <k> --value <lang>[:form]=<text> [--value ...]
                                [--sync ios|android|ios,android]
    lingua update <config.json> --batch <file.json>
                                [--sync ios|android|ios,android]

  Update one or more existing rows in place. Only the cells you supply are touched —
  unsupplied languages keep their current values. Same JSON schema as `lingua add --batch`.

  FLAGS
    --section <s>         Section containing the existing row.
    --key <k>             Key of the existing row.
    --value <l>[:f]=<t>   Per-language replacement value. Form override is optional —
                          by default Lingua targets whichever plural column the row uses.
    --batch <file>        JSON array of {section, key, values} entries.
    --sync <list>         Regenerate platform files after the update.

  EXAMPLES
    lingua update ./config.json --section onboarding --key cta_start \\
      --value en="Begin" --value de="Anfangen" --sync ios

    lingua update ./config.json --batch /tmp/edits.json --sync ios
  """

  static let findHelp = """
  USAGE
    lingua find <config.json> <query> [<query> ...] [--limit <N>]

  Substring-search the canonical sheet. Pass multiple queries to share a single sheet
  load — Lingua runs every query against the same snapshot.

  Single-query response shape:   {canonicalSheet, query, matches}
  Multi-query response shape:    {canonicalSheet, results: [{query, matches}, ...]}

  FLAGS
    --limit <N>           Maximum matches per query (default 10).

  EXAMPLES
    lingua find ./config.json "save changes"
    lingua find ./config.json "Settings" "Account" "Display name"
  """

  static let sectionsHelp = """
  USAGE
    lingua sections <config.json>

  List every section in the canonical sheet (with row range and sample keys), and report
  the list of language tabs so the caller knows which languages need values when adding.
  """

  static let listHelp = """
  USAGE
    lingua list <config.json> [--section <name>]

  Dump every (section, key, values) row from the canonical sheet. Multi-language values
  are included. Pass --section to filter to one section.
  """

  static let deleteHelp = """
  USAGE
    lingua delete <config.json> --section <s> --key <k>

  Delete a row by (section, key) from every language tab where it exists. Permissive —
  works even on misaligned tabs, so it's the recovery escape hatch for `tabs_out_of_sync`.

  FLAGS
    --section <s>         Section of the row to delete.
    --key <k>             Key of the row to delete.
  """

  static let syncHelp = """
  USAGE
    lingua sync <config.json> --platform ios|android

  Regenerate platform localization files from the Google Sheet. Same effect as the
  legacy `lingua ios` / `lingua android` commands but with a JSON status envelope.
  """

  static let doctorHelp = """
  USAGE
    lingua doctor <config.json>

  Run health checks against your Lingua configuration: API key, service account, sheet
  reachability, output dir writable, language-tab alignment. Exits non-zero if any
  check fails so CI can catch broken state early.
  """

  static let aiHelp = """
  USAGE
    lingua ai install   [--target claude|cursor|agents|both] [--global] [--force]
    lingua ai uninstall [--target claude|cursor|agents|both] [--global]
    lingua ai status

  Install / uninstall / inspect the bundled Agent Skills that teach Claude Code, Cursor,
  and other Agent-Skills-compatible runtimes how to drive Lingua. Default target is
  auto-detected from `.git/.claude/.cursor/.agents` in the resolved project root (or `~`
  for --global). `both` = claude + cursor only.

  FLAGS
    --target <t>          One of claude, cursor, agents, both.
    --global              Install into ~ instead of the project root.
    --force               Overwrite existing skill files (install only).
  """

  static let usage = """
  Lingua — localization tool for iOS / Android with AI-agent integration.

  USAGE
    lingua <command> [arguments]

  LOCALIZATION (read-only — needs only an API key)
    lingua ios     <config.json>           Generate iOS localization files + Lingua.swift
    lingua android <config.json>           Generate Android localization files
    lingua sync    <config.json> --platform ios|android
                                           Same as ios/android, with JSON status output

  AGENT-FACING SUBCOMMANDS (all emit JSON on stdout)
    lingua sections <config.json>          List sections in the canonical sheet
    lingua list     <config.json> [--section <name>]
                                           Dump all translations
    lingua find     <config.json> <query> [<query> ...]
                                           Search keys/sections/values. Multiple queries share
                                           a single sheet load.
    lingua add      <config.json> --section <s> --key <k> --value <lang>[:form]=<text> [--value ...]
                                           [--new-section] [--dry-run] [--sync ios|android|ios,android]
                                           Insert a new row inside the right section.
                                           --value en="Save"          (auto-picks plural column)
                                           --value en:one="1 item" --value en:other="%d items"
    lingua add      <config.json> --batch <file.json> [--new-section] [--dry-run]
                                           [--sync ios|android|ios,android]
                                           Insert many rows in a single round trip. The file
                                           is a JSON array of {section, key, values}; `values`
                                           may be {lang: "text"} or {lang: {form: "text"}}.
    lingua update   <config.json> --section <s> --key <k> --value <lang>[:form]=<text> [--value ...]
                                           [--sync ios|android|ios,android]
                                           Update an existing row's values in place
    lingua update   <config.json> --batch <file.json> [--sync ios|android|ios,android]
                                           Batched in-place updates. Same JSON shape as add.
    lingua delete   <config.json> --section <s> --key <k>
                                           Delete a row across all language tabs (recovery tool)
    lingua doctor   <config.json>          Verify config / auth / sheet alignment

  CONFIG SCAFFOLD
    lingua config init                     Generate a template lingua_config.json

  AI INTEGRATION
    lingua ai install   [--target claude|cursor|agents|both] [--global] [--force]
                                           Install bundled Agent Skills for Claude Code,
                                           Cursor (2.4+), and/or .agents/skills. Default
                                           target is auto-detected from the resolved project
                                           root (.git/.claude/.cursor/.agents) or ~ (global).
                                           both = claude+cursor only.
    lingua ai uninstall [--target claude|cursor|agents|both] [--global]
                                           Remove installed skills.
    lingua ai status                       Show what's installed and where (all five
                                           target/scope combinations).

  OTHER
    lingua help, --help, -h                Show this help
    lingua -v, --version                   Show Lingua version

  See https://github.com/poviolabs/Lingua for full docs.
  """
}
