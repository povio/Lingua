import Foundation

/// Embedded skill files for Lingua's agentic localization workflow. We inline these as Swift
/// string literals so the binary is fully self-contained — no resource bundle dance, no extra
/// Package.swift wiring, and they survive whatever distribution path Lingua takes (Homebrew,
/// Mac App Store, GitHub release).
///
/// Each skill carries two sets of metadata:
/// - `contents` is the original Claude Code SKILL.md (frontmatter + body) and is written
///   verbatim by `lingua ai install` for the Claude Code target.
/// - `cursorDescription` and `cursorGlobs` describe how the same skill should be exposed as a
///   Cursor `.mdc` rule. The `CursorRuleFormatter` uses these together with the markdown body
///   parsed out of `contents` to generate the Cursor-flavored file.
///
/// Markdown body is shared across both targets — only the frontmatter and the on-disk layout
/// differ.
enum BundledSkills {
  struct Skill {
    let name: String
    let contents: String
    let cursorDescription: String
    let cursorGlobs: [String]
  }

  /// File globs for the editing-flow skills. When a developer is editing UI code in any of
  /// these languages, Cursor auto-attaches the rule so the agent has the localization
  /// workflow available without needing to be told. The non-editing skills (regenerate,
  /// doctor) leave globs empty and rely on Cursor's "Agent Requested" mode (description match)
  /// instead.
  static let editingGlobs: [String] = [
    "**/*.swift",
    "**/*.kt",
    "**/*.kts",
    "**/*.tsx",
    "**/*.jsx",
    "**/*.dart"
  ]

  static let all: [Skill] = [
    Skill(
      name: "lingua-add-translation",
      contents: addTranslation,
      cursorDescription: "Add a new localized string to the project's Google Sheet via the Lingua CLI; use whenever the user asks for a new user-facing string or you're about to hardcode one.",
      cursorGlobs: editingGlobs
    ),
    Skill(
      name: "lingua-update-translation",
      contents: updateTranslation,
      cursorDescription: "Update an existing localized string in the project's Google Sheet via the Lingua CLI.",
      cursorGlobs: editingGlobs
    ),
    Skill(
      name: "lingua-find-key",
      contents: findKey,
      cursorDescription: "Search the project's Google Sheet for an existing localized key before creating a duplicate.",
      cursorGlobs: editingGlobs
    ),
    Skill(
      name: "lingua-regenerate",
      contents: regenerate,
      cursorDescription: "Regenerate platform localization files from the Google Sheet after sheet edits.",
      cursorGlobs: []
    ),
    Skill(
      name: "lingua-doctor",
      contents: doctor,
      cursorDescription: "Diagnose Lingua configuration / auth / sheet alignment problems.",
      cursorGlobs: []
    )
  ]

  static let addTranslation = """
  ---
  name: lingua-add-translation
  description: Add a new localized string to the project's Google Sheet via the Lingua CLI, then regenerate platform localization files. Use this whenever the user asks for a new user-facing string, or whenever you would otherwise hardcode a user-facing string in code.
  ---

  # Adding a new translation with Lingua

  Lingua manages localization in a Google Sheet and generates platform files (iOS `.strings` /
  `.stringsdict` / `Lingua.swift`, Android `strings.xml`) from it. Translations are organized
  by **section** (a logical group like `onboarding`, `errors`, `favorites`) and **key** (a
  `snake_case` identifier).

  **Never hardcode a user-facing string.** Use this skill to add it to the sheet first.

  ## Files you must NEVER create or hand-edit

  These are **generated** by `lingua sync` (or `lingua ios` / `lingua android`) from the Google
  Sheet. The sheet is the single source of truth.

  - `Lingua.swift` (the generated enum, usually under `Resources/Localization/`)
  - `**/*.lproj/Localizable.strings`
  - `**/*.lproj/Localizable.stringsdict`
  - Android `**/values*/strings.xml`

  If a `Lingua.<Section>.<key>` reference doesn't compile after you added a key, the answer is
  **never** to edit `Lingua.swift`. The answer is always one of:

  1. You forgot to run `lingua sync` after `lingua add` → run it now.
  2. The section name is lowercase but should be capitalized (`login` vs `Login`) → use
     `lingua delete` to remove the bad rows and re-add with the correct casing.
  3. The key contains characters that don't map cleanly to a Swift identifier → re-add with a
     valid `snake_case` key.

  ## Inputs you must gather before running

  - The English text of the new string.
  - The screen / feature it belongs to (used to pick the section).
  - The path to the project's `lingua_config.json`.

  ## Procedure

  1. **Check for an existing key first.** Duplication is the most common mistake.
     ```bash
     lingua find ./lingua_config.json "<english text>"
     ```
     If a close match exists, **stop and suggest reusing it** instead of creating a new key.

  2. **List existing sections + languages** so you place the new key in the right group AND
     know which languages need values.
     ```bash
     lingua sections ./lingua_config.json
     ```
     Read the JSON output. Two things matter:
     - `data.languages` is the list of language tabs in the sheet (e.g. `[{"code":"en",...},{"code":"de",...}]`).
       **You must provide a `--value` for every language code in this list** (see step 4).
       Skipping a language leaves the row blank in that tab and risks misaligning future
       writes.
     - `data.sections` is the list of existing sections. Pick the right one using these
       heuristics, in order:
       1. The feature folder of the file the new string will be used in
          (`Features/Onboarding/...` → `onboarding`).
       2. The closest existing section name semantically.
       3. As a **last resort**, propose a new section — explicitly tell the user
          *"I'm about to create a new section `X`, is that what you want?"* before passing
          `--new-section`.

  3. **Pick a `snake_case` key** that's specific to the screen/intent, not the literal text.
     Prefer `empty_state_message` over `no_favorites_yet` — keys should describe purpose, not
     content.

  4. **Add the row** with a `--value` for **every language** returned by `lingua sections`.
     If you don't speak a language, translate the English text yourself or ask the user — but
     never skip a language.
     ```bash
     lingua add ./lingua_config.json \\
       --section onboarding \\
       --key cta_start \\
       --value en="Get started" \\
       --value de="Loslegen"
     ```

     **Plural form column:** by default `lingua add` writes the value into whichever plural
     column the sheet's existing rows use (auto-detected — usually `one` for non-plural strings,
     matching the README template). You almost never need to think about this. Only override
     when adding an actually-plural string:
     ```bash
     lingua add ./lingua_config.json \\
       --section cart \\
       --key item_count \\
       --value en:one="1 item" --value en:other="%d items" \\
       --value de:one="1 Artikel" --value de:other="%d Artikel"
     ```
     The syntax is `<lang>:<form>=<text>` where `<form>` is one of `zero`, `one`, `two`, `few`,
     `many`, `other` (CLDR plural categories). For non-plural strings, omit the `:form` part
     entirely — Lingua will pick the right column for you.
     Parse the JSON response. Handle errors:
     - `error.code == "duplicate_key"` → stop, surface the existing row, suggest reusing it.
     - `error.code == "unknown_section"` → re-read `error.details.suggestions`, ask the user.
       **Do not auto-pass `--new-section`.**
     - `error.code == "tabs_out_of_sync"` → run `lingua doctor` and surface its output.
       Recovery: if you just created the orphan row, use
       `lingua delete ./lingua_config.json --section <s> --key <k>` to remove it from every
       tab where it exists, then retry the add with values for *all* languages.
     - `error.code == "missing_service_account"` → tell the user to set
       `serviceAccountKeyPath` in their `lingua_config.json` and run `lingua doctor`.

  5. **Regenerate platform files.**
     ```bash
     lingua sync ./lingua_config.json --platform ios
     ```
     (Also run with `--platform android` if both are configured.)

  6. **Use the new key in code** with the canonical reference syntax:
     - iOS: `Lingua.Section.key` (e.g. `Lingua.Onboarding.cta_start`)
     - Android: `R.string.section_key` (e.g. `R.string.onboarding_cta_start`)

  > **Section separators are automatic.** When `lingua add --new-section` creates a new
  > section in a non-empty sheet, it automatically leaves one blank row above the new section
  > for visual separation. You don't need to do anything; don't ask the user to add it
  > manually, and don't try to insert a blank row yourself.

  ## Hard rules

  - Always run `lingua find` and `lingua sections` *before* `lingua add`. Never skip them.
  - Never pass `--new-section` without explicit user confirmation.
  - **Never create or edit `Lingua.swift`, `Localizable.strings`, `Localizable.stringsdict`, or
    Android `strings.xml`.** They're regenerated from the sheet by `lingua sync`. If they look
    wrong, the fix is in the sheet (via `lingua add`/`update`/`delete`) followed by
    `lingua sync` — never with a text editor.
  - Never reach for `Write` or `Edit` on a file under `outputDirectory` or
    `swiftCode.outputSwiftCodeFileDirectory` from `lingua_config.json`. Those directories
    contain only generated artifacts.
  """

  static let updateTranslation = """
  ---
  name: lingua-update-translation
  description: Update the value of an existing localized string in the project's Google Sheet via the Lingua CLI, then regenerate platform localization files. Use when the user asks to fix wording, change a translation, or rename a localized message.
  ---

  # Updating an existing translation with Lingua

  ## Procedure

  1. **Find the row.**
     ```bash
     lingua find ./lingua_config.json "<text or key>"
     ```
     If multiple matches, ask the user which `(section, key)` to update.

  2. **Update in place.**
     ```bash
     lingua update ./lingua_config.json \\
       --section onboarding \\
       --key cta_start \\
       --value en="Begin" \\
       --value de="Anfangen"
     ```
     `lingua update` only touches the cells you specify. By default it updates whichever plural
     column the existing row uses (so non-plural strings stay non-plural). To target a specific
     plural form, use `--value <lang>:<form>=<text>`:
     ```bash
     lingua update ./lingua_config.json \\
       --section cart \\
       --key item_count \\
       --value en:other="%d things"
     ```

     Errors to handle:
     - `error.code == "not_found"` → the row doesn't exist; suggest `lingua-add-translation`.
     - `error.code == "tabs_out_of_sync"` → run `lingua doctor`.

  3. **Regenerate platform files.**
     ```bash
     lingua sync ./lingua_config.json --platform ios
     ```

  ## Hard rules

  - `update` never moves rows. It only changes values in place.
  - Only languages you pass with `--value` are touched. Others stay as-is.
  - **Never create or edit `Lingua.swift`, `Localizable.strings`, `Localizable.stringsdict`, or
    Android `strings.xml`.** They're regenerated from the sheet by `lingua sync`. If a string
    on screen still looks wrong after `lingua update`, run `lingua sync` again — don't reach
    for a text editor.
  """

  static let findKey = """
  ---
  name: lingua-find-key
  description: Search the project's Google Sheet for an existing localized string by key, section, or English text. Use this when you need to reference a localized string in code and want to avoid creating a duplicate key.
  ---

  # Finding an existing localized string

  Before referencing or creating any localized string, check if Lingua already has it.

  ```bash
  lingua find ./lingua_config.json "save changes"
  ```

  The JSON response contains a ranked list of matches with `section`, `key`, and `englishValue`.
  Use the canonical reference syntax for the platform you're editing:

  - iOS: `Lingua.Section.key` (e.g. `Lingua.Settings.save_changes`)
  - Android: `R.string.section_key` (e.g. `R.string.settings_save_changes`)

  If no match is found, use the `lingua-add-translation` skill to add a new key.
  """

  static let regenerate = """
  ---
  name: lingua-regenerate
  description: Regenerate platform localization files from the Google Sheet. Use this after the sheet has been edited externally, when generated files look stale, or after any add/update.
  ---

  # Regenerating localization files

  ```bash
  lingua sync ./lingua_config.json --platform ios
  lingua sync ./lingua_config.json --platform android
  ```

  Run only the platforms configured in `lingua_config.json`. After running, show
  `git diff --stat` of the output directory so the user can see what changed.

  If the sync fails, run the `lingua-doctor` skill.

  ## Generated files — never hand-edit

  Everything `lingua sync` writes is generated from the Google Sheet:

  - `Lingua.swift` (the generated enum)
  - `**/*.lproj/Localizable.strings`
  - `**/*.lproj/Localizable.stringsdict`
  - Android `**/values*/strings.xml`

  These files have a header comment saying *"This file was generated with Lingua command line
  tool. Please do not change it!"* — respect it.

  **If a generated file looks wrong:**

  - Empty or missing entries → the section name probably has wrong casing in the sheet (e.g.
    `login` instead of `Login`). Use `lingua list` to inspect, then `lingua delete` + re-add
    with the right casing.
  - Stale values → re-run `lingua sync`.
  - Missing entirely → check `outputDirectory` in `lingua_config.json` and run `lingua doctor`.

  **Never** "fix" a generated file by editing it directly. Any hand-edit is overwritten on the
  next `lingua sync`, and worse, it masks the real bug in the sheet.
  """

  static let doctor = """
  ---
  name: lingua-doctor
  description: Diagnose Lingua configuration problems — missing service account, unreachable sheet, misaligned language tabs, write permission issues. Use whenever any other Lingua command fails, or for first-time setup verification.
  ---

  # Diagnosing Lingua configuration

  ```bash
  lingua doctor ./lingua_config.json
  ```

  The JSON response contains a list of `checks`, each with `name`, `ok`, and `detail`. Walk
  through every failing check with the user:

  - **`config.apiKey` / `config.sheetId` missing** — fill them in `lingua_config.json`.
  - **`outputDirectory.writable` failed** — the path is wrong or not writable.
  - **`serviceAccount.load` failed** — the service account JSON file is missing or malformed.
    Walk the user through:
    1. Create a service account in Google Cloud Console.
    2. Download its JSON key.
    3. Share the Google Sheet with the service account's email (`...@...iam.gserviceaccount.com`).
    4. Set `serviceAccountKeyPath` in `lingua_config.json`.
  - **`sheet.reachable` failed** — wrong sheet ID, or the sheet isn't shared with the service
    account.
  - **`tabs.aligned` failed** — language tabs have different `(section, key)` rows. The user
    needs to manually realign them in the sheet before `lingua add` / `lingua update` will work.
  """
}
