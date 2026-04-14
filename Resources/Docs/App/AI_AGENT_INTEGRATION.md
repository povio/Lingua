# AI Agent Integration — Architecture

> Status: shipped. For end-user setup instructions see
> [`AI_AGENT_USAGE.md`](AI_AGENT_USAGE.md).

## Context

Lingua started as a human-driven tool: a developer edits a Google Sheet, then runs
`lingua ios <config>` to regenerate platform localization files. The agent integration extends
Lingua so an AI coding agent (Claude Code, Cursor, etc.) can drive the entire loop end-to-end:

1. Discover whether a translation key already exists, so it doesn't reinvent one.
2. Add a brand-new key + values to the **correct section** of the Google Sheet.
3. Regenerate platform localization files and reference the generated symbols in code.

Distribution constraint: Lingua ships via **Homebrew** and the **Mac App Store**. Users do
**not** clone the Lingua repo. Everything below has to be reachable from a `brew install`
(or App Store) install — no repo clone, no extra package, no separate server process.

Chosen approach: **Agent Skills**, the open standard implemented by Claude Code, Cursor 2.4+,
and other runtimes that read the same nested layout. The skill bodies are embedded inside the
Lingua binary as Swift string literals (no Package.swift resources to wire) and extracted on
demand by `lingua ai install`. Every install target uses the exact same on-disk format —
`<dir>/<skill-name>/SKILL.md` with `name` + `description` YAML frontmatter — so we ship a single
canonical body per skill and write it verbatim to whichever target the user picks (`.claude/skills/`,
`.cursor/skills/`, or `.agents/skills/`, project or global). The installer auto-detects which
target(s) the user has based on existing `.claude/`, `.cursor/`, and `.agents/` directories, so
the same command (`lingua ai install`) works across editors. The agent then drives Lingua through
the same set of agent-friendly subcommands regardless of where skills were installed.

---

## Approach Overview

Three layers, smallest to largest:

1. **CLI extensions** — new agent-friendly subcommands on the existing `lingua` binary. Read &
   write Google Sheets in a **section-aware** way that preserves blank separator rows.
2. **Bundled skill files** — markdown skill bodies embedded in the binary, installed by
   `lingua ai install` into `.claude/skills/lingua-*/SKILL.md` (Claude Code), `.cursor/skills/lingua-*/SKILL.md`
   (Cursor), and/or `.agents/skills/lingua-*/SKILL.md` (generic layout). All targets share the
   same on-disk format (the Agent Skills standard). Auto-detected from `.claude/`, `.cursor/`,
   and `.agents/` directories by default; overridable via `--target claude|cursor|agents|both`
   (`both` = Claude + Cursor only). Each target supports `--global`, writing to
   `~/.claude/skills/`, `~/.cursor/skills/`, and `~/.agents/skills/` respectively.
3. **Docs** — README section + the [end-user setup guide](AI_AGENT_USAGE.md).

---

## Layer 1 — CLI Extensions

New cases in `Sources/LinguaLib/Domain/Entities/Command.swift`, parsed by
`Sources/Lingua/Application/CommandLineParser/CommandLineParser.swift` and dispatched in
`Sources/Lingua/Application/Processor/AgentCommandDispatcher.swift`. All agent subcommands:

- Emit a stable JSON envelope on stdout (`{"ok": true, "data": ...}`).
- Exit non-zero on failure with `{"ok": false, "error": {"code", "message", "details"}}`
  written to stderr.
- Are non-interactive (no prompts) so an agent can call them safely.

### Subcommands

| Command | Purpose |
|---|---|
| `lingua sections <config>` | List every section in the canonical sheet with key count, row range, sample keys, **and the list of language tabs** so the agent knows which languages to provide values for. Primary input the agent uses to pick the right section and to know what languages to translate to. |
| `lingua list <config> [--section <s>]` | Dump every (section, key, values) row. Optional section filter. |
| `lingua find <config> <query> [--limit N]` | Substring search across keys, sections, and English values. Returns ranked matches. Used to avoid duplicate keys. |
| `lingua add <config> --section <s> --key <k> --value <lang>[:form]=<text> [--value …] [--new-section] [--dry-run]` | Insert a new row inside the right section. Rejects unknown sections unless `--new-section`. Auto-inserts a blank separator row above brand-new sections. |
| `lingua update <config> --section <s> --key <k> --value <lang>[:form]=<text> [--value …]` | Update one or more cells of an existing row in place. Auto-targets the existing plural-form column unless an explicit `:form` is given. |
| `lingua delete <config> --section <s> --key <k>` | Delete a row from every language tab where it exists. Recovery escape hatch — works on misaligned tabs. |
| `lingua sync <config> --platform ios\|android` | Same as today's `lingua ios` / `lingua android` but with structured JSON status output. The old commands remain as aliases. |
| `lingua doctor <config>` | Verifies config, API key, service account, sheet reachability, output dirs writable, all language tabs aligned. Exits non-zero if any check fails. |
| `lingua ai install [--target claude\|cursor\|agents\|both] [--global] [--force]` | Extracts bundled Agent Skills into `.claude/skills/lingua-*/SKILL.md` (Claude Code), `.cursor/skills/lingua-*/SKILL.md` (Cursor), and/or `.agents/skills/lingua-*/SKILL.md`. Default target is auto-detected from `.claude/`, `.cursor/`, and `.agents/` — cwd for project scope, `~` for `--global`. |
| `lingua ai uninstall [--target claude\|cursor\|agents\|both] [--global]` | Removes installed skills. |
| `lingua ai status` | Shows what's installed and where, across all five target × scope combinations (Claude, Cursor, and `.agents`, each project / global). |
| `lingua help` (also `--help`, `-h`, or bare `lingua`) | Prints usage. |

### Section-aware insertion (the important part)

The default Sheets read path treats sections as a column value with no positional meaning. For
agent-driven writes we need *positional* awareness so the sheet stays human-readable: a new key
for `onboarding` must land **inside** the `onboarding` block, not at the bottom of the sheet,
and a new section must have a blank row above it for visual separation.

To make this work without breaking row math when sheets contain blank rows, every
`LocalizationEntry` carries a `sheetRow: Int` field populated by the decoder from the actual
row index in the raw `SheetDataResponse.values`. Blank rows in the middle are skipped from the
decoded `entries` array but the indices keep advancing, so `sheetRow` always reflects the
physical row number in the Google Sheet UI. Every use case computes target rows from
`entry.sheetRow` rather than from the entries-array index.

**Algorithm for `lingua add`:**

1. Load every language tab via `SheetDataLoader`.
2. Pick a **canonical tab** (`config.localization.defaultWriteSheet`, fallback: first tab whose
   languageCode is `en`, then the first tab).
3. **Validate alignment:** every other language tab must have the same `(section, key)` rows in
   the same order. If not, abort with `error.code = "tabs_out_of_sync"` and tell the agent to
   run `lingua doctor`. Silent writes into a misaligned sheet would corrupt the localization.
4. **Reject duplicates:** if `(section, key)` already exists anywhere in the canonical tab,
   abort with `error.code = "duplicate_key"`.
5. **Resolve target section:**
   - **Section exists:** find the last entry in that section, set `insertionRow =
     lastEntryInSection.sheetRow + 1`.
   - **Section is new, `--new-section` not passed:** abort with `error.code = "unknown_section"`
     and a list of the 3 closest existing section names by Levenshtein distance in
     `error.details.suggestions`.
   - **Section is new, `--new-section` passed:** set `insertionRow =
     lastEntryOverall.sheetRow + 2` (leaving exactly one blank row for visual separation), or
     `2` for an empty sheet.
6. **Resolve plural form column:** detect the sheet's default convention by inspecting existing
   rows — whichever of `one` / `other` is more common is the default for non-plural strings.
   Empty sheets default to `one`. Assignments with `--value lang:form=text` use the explicit
   form; assignments with `--value lang=text` use the detected default.
7. **Write the same row position to every language tab** so they stay aligned. Languages with
   no supplied value get a row with blank value cells (section + key still present).
   - For brand-new sections: deterministic `values.update` at the resolved row index. We do
     **not** use Google's `:append` endpoint because its non-deterministic table detection can
     silently drop tabs whose only populated cell is metadata.
   - For inserts inside an existing section:
     `spreadsheets.batchUpdate` with `InsertDimensionRequest` to shift existing rows down,
     followed by `spreadsheets.values.update` on the new row's range.

**Algorithm for `lingua update`:**

1. Same load + alignment check as above.
2. Find the row with `(section, key)` in the canonical tab; abort with
   `error.code = "not_found"` if missing.
3. Detect the form to update: if the existing row has only `one` populated, target `one`; if
   only `other`, target `other`; otherwise fall back to sheet-wide default detection. Explicit
   `--value lang:form=text` overrides this.
4. For each language tab where a `--value` was supplied, write only the specific cell via
   `values.update`. Cells for languages not supplied stay untouched.

**Algorithm for `lingua delete`:**

Permissive — does **not** require tab alignment, since the whole point is recovery from broken
state. For each language tab independently, find rows matching `(section, key)` and delete
them via `batchUpdate` + `DeleteDimensionRequest`, highest row index first per tab so earlier
deletions don't shift later target rows.

### JSON output examples

`lingua add` success:

```json
{
  "ok": true,
  "data": {
    "section": "onboarding",
    "key": "cta_start",
    "rowIndex": 9,
    "createdNewSection": false,
    "resolvedDefaultForm": "one",
    "languagesWritten": ["en_US_English", "de_DE_German"],
    "languagesSkipped": [],
    "dryRun": false
  }
}
```

`lingua add` failure (unknown section with suggestions):

```json
{
  "ok": false,
  "error": {
    "code": "unknown_section",
    "message": "Section 'onboardin' does not exist. Pass --new-section to create it. Closest matches: onboarding, errors, welcome",
    "details": { "suggestions": "onboarding,errors,welcome" }
  }
}
```

### Plural form handling

The sheet's column layout (mirrors `SheetTranslationBuilder`):

```
A          B    C        D       E       F       G       H
section    key  zero     one     two     few     many    other
```

This is centralized in `Sources/LinguaLib/Domain/UseCases/Agent/PluralColumnLayout.swift` —
the only place that knows column geometry, so future layout changes only need to touch one
file.

CLI surface for plurals:

```bash
# Non-plural (auto-detected default form, usually "one")
--value en="Save"

# Explicit plural forms
--value en:one="1 item" --value en:other="%d items"
```

Forms must be one of `zero`, `one`, `two`, `few`, `many`, `other` (CLDR plural categories) —
unknown forms are rejected with `error.code = "invalid_plural_form"`.

### Config additions

Extends `ConfigDto` (`Sources/LinguaLib/Infrastructure/Data/Configuration/ConfigDto.swift`)
with two new optional fields:

```json
{
  "localization": {
    "apiKey": "<google_api_key>",
    "sheetId": "<google_spreadsheet_id>",
    "outputDirectory": "...",
    "swiftCode": { ... },
    "serviceAccountKeyPath": "/path/to/lingua-sa.json",
    "defaultWriteSheet": "en_US_English"
  }
}
```

`serviceAccountKeyPath` and `defaultWriteSheet` are both optional. Read-only commands keep
working with just the API key. Old configs keep parsing — fully backwards compatible.

### Google Sheets write path

```
Sources/LinguaLib/Infrastructure/Data/GoogleSheets/
├── Fetcher/                            (existing — read)
└── Writer/                             (new)
    ├── GoogleSheetsWriter.swift              // protocol GoogleSheetsWriting + impl
    ├── ServiceAccountTokenProvider.swift     // RS256 JWT → OAuth2 access_token, in-memory cache
    ├── ServiceAccountKey.swift               // PEM JSON loader
    └── RSAPrivateKey.swift                   // PKCS#8 → PKCS#1 DER + Security.framework signing
```

`GoogleSheetsWriter` exposes five operations consumed by the agent use cases:
`insertRow` (`batchUpdate` + `InsertDimensionRequest` + `values.update`),
`updateRow` (deterministic `values.update`),
`appendRow` (legacy `:append`, kept for completeness but not used by the section-aware path),
`updateCell`, and
`deleteRow`. Tab names are looked up to numeric `gid` once per process and cached.

Auth: build an RS256-signed JWT from the service account JSON, exchange it at
`https://oauth2.googleapis.com/token` for a short-lived access token, cache it in memory until
just before expiry. RSA signing uses the macOS Security framework directly (no external crypto
dependency) — `RSAPrivateKey` parses the PKCS#8 PEM, strips the AlgorithmIdentifier wrapper to
PKCS#1 form, and calls `SecKeyCreateSignature` with `.rsaSignatureMessagePKCS1v15SHA256`.

### Domain layer additions

New use cases in `Sources/LinguaLib/Domain/UseCases/Agent/`:

- `ListSectionsUseCase` — returns ordered `SectionSummary` list + the language tabs.
- `ListTranslationsUseCase` — full dump, optionally section-filtered.
- `FindTranslationUseCase` — substring search ranked by where it matched.
- `AddTranslationUseCase` — section-aware insertion algorithm above.
- `UpdateTranslationUseCase` — in-place value updates.
- `DeleteTranslationUseCase` — permissive cross-tab delete (recovery).
- `DoctorUseCase` — runs the doctor checks.
- `PluralColumnLayout` — column geometry helpers + default-form detection.
- `CanonicalSheetSelector` — picks the canonical tab from the available language sheets.

All wired through `AgentModuleFactory`, which is the single composition root the CLI dispatcher
uses. Service account loading happens lazily inside the factory only for write-path use cases,
so read-only commands work without `serviceAccountKeyPath` configured.

---

## Layer 2 — Bundled Skills

Skills are stored as Swift string literals in
`Sources/Lingua/Application/Processor/BundledSkills.swift` — no Swift Package resource bundle,
no `.process` rule in `Package.swift`. This was a deliberate simplification from the original
plan: the skills are short, the binary is the source of truth, and inlining them avoids any
resource-bundle indirection. `SkillInstaller` reads them directly from the constants and writes
them to disk on `lingua ai install`.

### Multi-target install (Claude Code + Cursor + `.agents`)

Claude Code, Cursor 2.4+, and other Agent Skills–compatible layouts use the same nested format,
so the same skill body is written verbatim to whichever target the user picks.
`SkillInstaller.Target` only distinguishes the parent directory:

| Target × Scope | Path |
|---|---|
| `.claudeCode` + `.project` | `./.claude/skills/<name>/SKILL.md` |
| `.claudeCode` + `.global`  | `~/.claude/skills/<name>/SKILL.md` |
| `.cursor` + `.project`     | `./.cursor/skills/<name>/SKILL.md` |
| `.cursor` + `.global`      | `~/.cursor/skills/<name>/SKILL.md` |
| `.agents` + `.project`     | `./.agents/skills/<name>/SKILL.md` |
| `.agents` + `.global`      | `~/.agents/skills/<name>/SKILL.md` |

`lingua ai install` resolves the target list in this order:

1. Explicit `--target claude|cursor|agents|both` wins (`both` = Claude + Cursor only).
2. Otherwise `SkillInstaller.autoDetectTargets(in: root)` checks for `.cursor/`, `.claude/`, and
   `.agents/` directories: each present directory adds that target; none present → fall back to
   `[.claudeCode]` so brand-new projects keep the original behavior. The detection root is the
   cwd for project scope and the user's home directory for `--global`.

The install / uninstall envelope reports per-target results plus a flag indicating whether
auto-detection picked the targets, so callers can tell when they got the default vs an
explicit choice:

```json
{
  "ok": true,
  "data": {
    "targets": [
      { "target": "cursor", "scope": "project", "directory": "/path/.cursor/skills", "installed": [...] },
      { "target": "claude", "scope": "project", "directory": "/path/.claude/skills", "installed": [...] }
    ],
    "auto_detected": true
  }
}
```

> Cursor also natively reads `.claude/skills/` and `~/.claude/skills/` for compatibility, so
> a `--target claude` install is already visible to Cursor. The `--target cursor` path exists
> for users who want their skills explicitly under `.cursor/` (e.g. for a Cursor-only repo, or
> to keep the two editors' skill sets isolated).

### The skills

| Skill | Triggers when… | Calls |
|---|---|---|
| `lingua-add-translation` | User asks to add a localized string, OR the agent is about to hardcode a user-facing string. | `find` → `sections` → `add` → `sync` |
| `lingua-update-translation` | User asks to fix wording / change a translation. | `find` → `update` → `sync` |
| `lingua-find-key` | Agent needs an existing localized string for a screen it's editing. | `find` |
| `lingua-regenerate` | Sheet was edited externally, generated files look stale. | `sync` |
| `lingua-doctor` | Any other Lingua command fails, or first-time setup. | `doctor` |

Each skill teaches the agent a strict procedure plus a set of hard rules. The most important
rules baked into `lingua-add-translation` and `lingua-update-translation`:

- Always run `lingua find` and `lingua sections` *before* `lingua add`.
- Never pass `--new-section` without explicit user confirmation.
- Provide a `--value` for **every** language returned by `lingua sections.languages`. Skipping
  a language leaves the row blank in that tab and risks misalignment on future writes.
- For non-plural strings, omit the `:form` part of `--value` and let Lingua auto-pick the
  column. For actual plurals, use explicit `--value lang:one="…" --value lang:other="…"`.
- **Never create or hand-edit `Lingua.swift`, `Localizable.strings`, `Localizable.stringsdict`,
  or Android `strings.xml`.** They're regenerated from the sheet by `lingua sync`. If they
  look wrong, the fix is in the sheet.
- Recovery from `tabs_out_of_sync`: use `lingua delete` to remove orphan rows, then re-add
  with values for all languages.

### Install UX

```bash
brew install lingua                # one-time, system-wide
cd MyAwesomeApp                    # the consumer's iOS/Android project
lingua config init                 # creates lingua_config.json (existing command)
lingua ai install                  # drops .claude/skills/lingua-*/ in cwd
git add .claude lingua_config.json
```

Anyone who later clones `MyAwesomeApp` and opens Claude Code automatically has the skills,
because `.claude/` is committed. They just need `brew install lingua` themselves so the binary
the skills invoke exists on their PATH.

`lingua ai install --global` writes to `~/.claude/skills/` instead, for developers who work
across many Lingua-using repos.

App Store build: same skills, installable via a "Set up AI integration in folder…" menu item
that uses an `NSOpenPanel` to get sandbox access to the project folder. (Not yet implemented
in the App Store target — only the CLI today.)

---

## Layer 3 — Docs

- **README:** *"Using Lingua with an AI coding agent"* section — install command + skill list
  + link to the full setup doc.
- **`Resources/Docs/App/AI_AGENT_USAGE.md`:** end-user setup guide. Service account creation
  (Google Cloud Console → IAM → Service Accounts → JSON key → share sheet with SA email),
  config schema, JSON contract for every subcommand, example agent transcript.
- **This file:** architecture / why-it-works-this-way reference.

---

## Critical Files

**Domain (`Sources/LinguaLib/Domain/`):**

- `Entities/Command.swift` — adds `sections`, `list`, `find`, `add`, `update`, `delete`,
  `sync`, `doctor`, `ai`, `install`, `uninstall`, `status`, `help`.
- `Entities/LocalizationEntry.swift` — gains `sheetRow: Int`. `Equatable` ignores it so existing
  test fixtures keep working.
- `Entities/Config.swift` + `Infrastructure/Data/Configuration/ConfigDto.swift` /
  `ConfigDtoTransformer.swift` / `Config+Default.swift` — add `serviceAccountKeyPath`,
  `defaultWriteSheet`.
- `UseCases/Agent/` — all the agent use cases listed above, plus `PluralColumnLayout`,
  `CanonicalSheetSelector`, `AgentModuleFactory`.

**Infrastructure (`Sources/LinguaLib/Infrastructure/`):**

- `Data/GoogleSheets/Decoder/LocalizationSheetDataDecoder.swift` — populates `sheetRow` from
  raw row index so blank rows are correctly tracked.
- `Data/GoogleSheets/Writer/` (new directory) — `GoogleSheetsWriter`,
  `ServiceAccountTokenProvider`, `ServiceAccountKey`, `RSAPrivateKey`.
- `Application/Output/AgentJSONOutput.swift` — shared `{ok, data}` / `{ok, error}` envelope
  used by every agent subcommand.

**CLI surface (`Sources/Lingua/Application/`):**

- `CommandLineParser/CommandLineParser.swift` — extended to parse the new subcommands and
  flag forms (including `--value lang[:form]=text`).
- `Processor/LocalizationProcessor.swift` — dispatches new commands to `AgentCommandDispatcher`.
- `Processor/AgentCommandDispatcher.swift` — agent command dispatch + JSON formatting.
- `Processor/SkillInstaller.swift` — installs / uninstalls / status of bundled skills, with
  `Target.claudeCode` / `Target.cursor` / `Target.agents` and `autoDetectTargets(in:)`. All
  targets share the same nested `<dir>/<name>/SKILL.md` layout.
- `Processor/BundledSkills.swift` — the five skill bodies as Swift string literals.
- `Processor/HelpText.swift` — usage text printed by `lingua help`.

**Tests (`Tests/LinguaTests/`):**

- `Domain/UseCases/Agent/AddTranslationUseCaseTests.swift` — section-aware insertion across
  every error path, including auto-separator behavior, sheet-row preservation, and plural form
  resolution.
- `Domain/UseCases/Agent/UpdateTranslationUseCaseTests.swift` — in-place updates, plural form
  targeting, not-found errors.
- `Domain/UseCases/Agent/DeleteTranslationUseCaseTests.swift` — per-tab independence, recovery
  on misaligned tabs.
- `Domain/UseCases/Agent/FindAndSectionsTests.swift` — section summaries with blank separator
  rows; find ranking.
- `Application/Processor/SkillInstallerTests.swift` — Claude Code + Cursor + `.agents` install /
  idempotency / uninstall, auto-detection across empty / single-target / multi-target folders.

---

## Verification

1. **Unit tests** (`swift test`) — full suite passes, including agent layer coverage
   (section-aware insertion, plural form handling, blank-row preservation, delete recovery,
   skill installer for Claude, Cursor, and `.agents`).

2. **End-to-end against a real sheet** — see the smoke-test sequence in
   [`AI_AGENT_USAGE.md`](AI_AGENT_USAGE.md). Verified workflows:
   - `lingua doctor` reports all checks green.
   - `lingua sections` returns sections with correct row ranges and the language list.
   - `lingua find` returns ranked matches.
   - `lingua add ... --new-section` creates a new section with a blank separator row above it.
   - Subsequent `lingua add` to the same new section places the row at the correct sheet row,
     skipping the blank separator.
   - `lingua update` writes only the cells you specify, leaving others untouched.
   - `lingua delete` cleans up across all language tabs.
   - `lingua sync --platform ios` regenerates `Localizable.strings` / `.stringsdict` and
     `Lingua.swift` from the updated sheet.

3. **Skill smoke test in Claude Code** — verified end-to-end against the example iOS app:
   *"Localize all the user-facing strings in `SettingsView.swift`"* triggers the
   `lingua-add-translation` skill, which runs `find` → `sections` → `add` (with explicit
   plural form syntax for plural keys) → `sync`, then edits the SwiftUI view to reference
   `Lingua.Settings.*` symbols. New sections land with auto-separator rows above them.

4. **Backwards compatibility** — confirmed:
   - `lingua ios <old config>` (no `serviceAccountKeyPath`, no `defaultWriteSheet`) works
     unchanged.
   - `config init` template stays compatible; new optional fields can be added without
     breaking old configs.
   - `lingua ios` and `lingua android` continue to exist as the legacy entry points alongside
     `lingua sync --platform …`.
