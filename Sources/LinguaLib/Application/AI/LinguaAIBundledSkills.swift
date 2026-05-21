import Foundation

/// Embedded skill files for Lingua's agentic localization workflow. We inline these as Swift
/// string literals so the binary is fully self-contained and can install the same skills from
/// both the CLI and the macOS app.
public enum LinguaAIBundledSkills {
  public struct Skill {
    public let name: String
    public let contents: String

    public init(name: String, contents: String) {
      self.name = name
      self.contents = contents
    }
  }

  public static let all: [Skill] = [
    Skill(name: "lingua-add-translation", contents: addTranslation),
    Skill(name: "lingua-update-translation", contents: updateTranslation),
    Skill(name: "lingua-find-key", contents: findKey),
    Skill(name: "lingua-regenerate", contents: regenerate),
    Skill(name: "lingua-doctor", contents: doctor)
  ]

  public static let addTranslation = """
  ---
  name: lingua-add-translation
  description: Add one or more localized strings to the project's Google Sheet via the Lingua CLI, then regenerate platform localization files. Use this whenever the user asks for a new user-facing string, or whenever you would otherwise hardcode a user-facing string in code.
  ---

  # Adding new translations with Lingua

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

  1. You forgot to run `lingua sync` after `lingua add` → run it now (or use `--sync ios`
     on the add).
  2. The section name is lowercase but should be capitalized (`login` vs `Login`) → use
     `lingua delete` to remove the bad rows and re-add with the correct casing.
  3. The key contains characters that don't map cleanly to a Swift identifier → re-add with a
     valid `snake_case` key.

  ## Inputs you must gather before running

  - The English text of every new string (gather them ALL up front, even if there are 20).
  - The screen / feature they belong to (used to pick the section).
  - The path to the project's `lingua_config.json`.

  ## Procedure

  1. **Check for existing keys first** with a single multi-query find — this avoids three
     separate sheet fetches when you have several candidates:
     ```bash
     lingua find ./lingua_config.json "settings" "account" "display name"
     ```
     If a close match exists, **stop and suggest reusing it** instead of creating a new key.

  2. **List existing sections + languages** so you place the new keys in the right group AND
     know which languages need values.
     ```bash
     lingua sections ./lingua_config.json
     ```
     Read the JSON output. Two things matter:
     - `data.languages` is the list of language tabs in the sheet (e.g. `[{"code":"en",...},{"code":"de",...}]`).
       **You must provide a value for every language code in this list.** Skipping a language
       leaves the row blank in that tab and risks misaligning future writes.
     - `data.sections` is the list of existing sections. Pick the right one using these
       heuristics, in order:
       1. The feature folder of the file the new string will be used in
          (`Features/Onboarding/...` → `onboarding`).
       2. The closest existing section name semantically.
       3. As a **last resort**, propose a new section — explicitly tell the user
          *"I'm about to create a new section `X`, is that what you want?"* before passing
          `--new-section`.

  3. **Pick a `snake_case` key** for each string that's specific to the screen/intent, not the
     literal text. Prefer `empty_state_message` over `no_favorites_yet` — keys should describe
     purpose, not content.

  4. **Submit ALL strings in one batched call.** This is dramatically faster than chaining
     individual `lingua add` invocations (each one re-fetches the whole sheet and re-signs the
     service account JWT). Write the entries to a JSON file and pass it via `--batch`. Always
     include `--sync ios` (and/or `--sync android`) so the platform files are regenerated in
     the same invocation.

     **`/tmp/lingua-batch.json`** — bare JSON array, plain strings for non-plural, `{form:
     text}` objects for plurals:
     ```json
     [
       {"section": "Settings", "key": "title", "values": {"en": "Settings", "de": "Einstellungen"}},
       {"section": "Settings", "key": "account", "values": {"en": "Account", "de": "Konto"}},
       {"section": "Settings", "key": "item_count", "values": {
         "en": {"one": "1 item", "other": "%d items"},
         "de": {"one": "1 Artikel", "other": "%d Artikel"}
       }}
     ]
     ```

     ```bash
     lingua add ./lingua_config.json --batch /tmp/lingua-batch.json --sync ios
     # Add --new-section if the batch introduces a section that doesn't exist yet.
     # --new-section is a BOOLEAN switch — it takes NO value. The section name lives in
     # the JSON. Wrong: `--new-section Settings`. Right: just `--new-section`.
     # Add --sync android too (or use --sync ios,android) if the project ships for Android.
     ```

     Plural forms must be one of `zero`, `one`, `two`, `few`, `many`, `other` (CLDR plural
     categories). For non-plural strings, use the plain `"<lang>": "<text>"` form — Lingua
     picks the right column automatically.

     **Only fall back to per-string flags** if you're truly adding exactly one key:
     ```bash
     lingua add ./lingua_config.json --section onboarding --key cta_start \\
       --value en="Get started" --value de="Loslegen" --sync ios
     ```

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

  5. **Use the new keys in code.** The sheet stores `snake_case`, but the generated code on
     each platform transforms it. **Never call the snake_case key from code** — always use
     the transformed identifier the generator produced.

     **iOS — non-plural keys** become `Lingua.<PascalSection>.<camelKey>`:
     - Section `general`, key `app_description` → `Lingua.General.appDescription`.
     - **Not** `Lingua.General.app_description`. Section is PascalCase, key is camelCase.

     **iOS — plural keys** become `Lingua.<PascalSection>.<camelKey>(_:)` — a function that
     takes the count and returns the localized string:
     - Section `settings`, key `photo_count` (plural) → `Lingua.Settings.photoCount(photoCount)`.
     - The count argument is required for plurals; the generated stringsdict resolves it via
       `%d`. If you see a plain `Lingua.Settings.photoCount` it won't compile — pass the count.

     **Android — `R.string.<section>_<key>`** (lowercased, snake_case preserved):
     - Identifier is `(section + "_" + key).lowercased()`.
       Example: section `General`, key `app_description` → `R.string.general_app_description`.
     - Unlike iOS, Android keeps `snake_case`. Don't camelCase it.
     - When in doubt, grep `strings.xml` for the `<string name="...">` entry and use that
       name verbatim.

     Reserved Swift identifiers get backticked automatically (`class` → `` `class` ``).
     If a reference doesn't compile, the cause is almost always (a) you wrote `snake_case`
     instead of `camelCase`, or (b) you forgot the `(_:)` count argument on a plural.

  > **Section separators are automatic.** When `lingua add --new-section` creates a new
  > section in a non-empty sheet, it automatically leaves one blank row above the new section
  > for visual separation. You don't need to do anything; don't ask the user to add it
  > manually, and don't try to insert a blank row yourself.

  ## Hard rules

  - Always run `lingua find` and `lingua sections` *before* `lingua add`. Never skip them.
  - **Prefer `--batch` for any non-trivial add** (≥ 2 strings, or when section/plural mix
    means you'd otherwise chain commands). One batched call replaces N sequential ones, and
    each sequential `lingua add` costs ~3–5 seconds of fixed overhead.
  - Always pair the add with `--sync ios` (or `--sync ios,android`) so the platform files
    regenerate in the same invocation — saves another full sheet round-trip.
  - Never pass `--new-section` without explicit user confirmation.
  - **Never create or edit `Lingua.swift`, `Localizable.strings`, `Localizable.stringsdict`, or
    Android `strings.xml`.** They're regenerated from the Google Sheet by `lingua sync`. If they look
    wrong, the fix is in the sheet (via `lingua add`/`update`/`delete`) followed by
    `lingua sync` — never with a text editor.
  - Never reach for `Write` or `Edit` on a file under `outputDirectory` or
    `swiftCode.outputSwiftCodeFileDirectory` from `lingua_config.json`. Those directories
    contain only generated artifacts.
  """

  public static let updateTranslation = """
  ---
  name: lingua-update-translation
  description: Update one or more existing localized strings in the project's Google Sheet via the Lingua CLI, then regenerate platform localization files. Use when the user asks to fix wording, change a translation, or rename a localized message.
  ---

  # Updating existing translations with Lingua

  ## Procedure

  1. **Find the row(s).** Pass every search term in a single multi-query find so the sheet is
     only loaded once:
     ```bash
     lingua find ./lingua_config.json "<text or key>" "<another>"
     ```
     If multiple matches, ask the user which `(section, key)` to update.

  2. **Update in place.** For two or more keys, batch them — the per-call sheet fetch /
     auth cost is the same whether you change one cell or one hundred, so don't pay it twice.

     **`/tmp/lingua-update.json`** — same shape as `lingua add --batch`:
     ```json
     [
       {"section": "Settings", "key": "title", "values": {"en": "Preferences", "de": "Einstellungen"}},
       {"section": "Cart", "key": "item_count", "values": {
         "en": {"other": "%d things"}
       }}
     ]
     ```
     ```bash
     lingua update ./lingua_config.json --batch /tmp/lingua-update.json --sync ios
     ```

     **Single-key fallback** (only when you have exactly one row to change):
     ```bash
     lingua update ./lingua_config.json --section onboarding --key cta_start \\
       --value en="Begin" --value de="Anfangen" --sync ios
     ```

     `lingua update` only touches the cells you specify. By default it updates whichever plural
     column the existing row already uses (so non-plural strings stay non-plural). To target a
     specific plural form, use the `{form: text}` object form in the batch JSON, or
     `--value <lang>:<form>=<text>` on the CLI.

     Errors to handle:
     - `error.code == "not_found"` (single mode) or a non-empty `data.notFound[]` (batch mode)
       → the row doesn't exist; suggest `lingua-add-translation`.
     - `error.code == "tabs_out_of_sync"` → run `lingua doctor`.

  3. **Reference the key from code with the platform-transformed identifier**, never the raw
     `snake_case` key from the sheet:
     - **iOS non-plural**: `Lingua.<PascalSection>.<camelKey>` — section becomes `PascalCase`,
       key becomes `camelCase`. e.g. sheet `General / app_description` →
       `Lingua.General.appDescription`. **Not** `Lingua.General.app_description`.
     - **iOS plural**: `Lingua.<PascalSection>.<camelKey>(_:)` — takes the count argument.
       e.g. sheet `Settings / photo_count` → `Lingua.Settings.photoCount(photoCount)`.
     - **Android**: `R.string.<section>_<key>` lowercased, snake_case preserved. e.g.
       `R.string.general_app_description`.
     - If unsure, open the regenerated `Lingua.swift` / `strings.xml` and copy the symbol.

  ## Hard rules

  - `update` never moves rows. It only changes values in place.
  - Only languages you pass values for are touched. Others stay as-is.
  - **Prefer `--batch` and `--sync` together** for any non-trivial update — same speed
    rationale as `lingua-add-translation`.
  - **Never create or edit `Lingua.swift`, `Localizable.strings`, `Localizable.stringsdict`, or
    Android `strings.xml`.** They're regenerated from the Google Sheet by `lingua sync`. If a string
    on screen still looks wrong after `lingua update`, run `lingua sync` again — don't reach
    for a text editor.
  """

  public static let findKey = """
  ---
  name: lingua-find-key
  description: Search the project's Google Sheet for an existing localized string by key, section, or English text. Use this when you need to reference a localized string in code and want to avoid creating a duplicate key.
  ---

  # Finding an existing localized string

  Before referencing or creating any localized string, check if Lingua already has it.

  ```bash
  lingua find ./lingua_config.json "save changes"
  ```

  When you have **several candidate strings** to look up, pass them as additional positional
  arguments in one call — Lingua loads the sheet once and runs every search against the same
  snapshot:

  ```bash
  lingua find ./lingua_config.json "save changes" "discard" "are you sure"
  ```

  The single-query call returns `{canonicalSheet, query, matches}`. The multi-query call
  returns `{canonicalSheet, results}` where each `results[i]` has its own `query` and
  `matches`.

  Each match contains `section`, `key`, and `englishValue`.
  Use the platform-transformed identifier — never the raw `snake_case` key from the sheet:

  - **iOS**: `Lingua.<PascalSection>.<camelKey>` — section is `PascalCase`, key is `camelCase`.
    e.g. sheet `Settings / save_changes` → `Lingua.Settings.saveChanges`. **Not**
    `Lingua.Settings.save_changes`.
  - **Android**: `R.string.<section>_<key>` lowercased, snake_case preserved. e.g.
    `R.string.settings_save_changes`.
  - If unsure, open the generated `Lingua.swift` / `strings.xml` and copy the exact symbol.

  If no match is found, use the `lingua-add-translation` skill to add a new key.
  """

  public static let regenerate = """
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

  public static let doctor = """
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
