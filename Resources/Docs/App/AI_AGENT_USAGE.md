# Using Lingua with an AI coding agent

Lingua ships with bundled [Agent Skills](https://agentskills.io/) for [Claude Code](https://docs.claude.com/claude-code), [Cursor](https://cursor.com/docs/skills) (2.4+), and `.agents/skills/` (same standard layout), plus a set of agent-friendly subcommands. An AI coding agent can drive the entire localization loop autonomously: discover existing keys, add new translations to your Google Sheet (in the **right section**), regenerate platform files, and reference the new key in code.

This guide walks you through the one-time setup and the agent surface.

---

## 1. Install the skills

After installing Lingua via Homebrew (or downloading the binary), `cd` into your iOS / Android project and run:

```shell
lingua ai install
```

Both Claude Code and Cursor 2.4+ implement the same Agent Skills standard (`<dir>/<skill>/SKILL.md`), so Lingua ships a single canonical body per skill and writes it verbatim to whichever target you pick.

By default, `lingua ai install` **walks up from the cwd to resolve the project root**, looking for `.git`, `.claude`, `.cursor`, or `.agents`, and then auto-detects which integration(s) to install there:

- If `.cursor/` exists at the resolved root → installs into `.cursor/skills/lingua-*/SKILL.md`.
- If `.claude/` exists at the resolved root → installs into `.claude/skills/lingua-*/SKILL.md`.
- If `.agents/` exists at the resolved root → installs into `.agents/skills/lingua-*/SKILL.md`.
- Any combination of the above → installs each detected target.
- If none exist anywhere up the tree → falls back to Claude Code in the current directory.

Commit whatever it writes. From that point forward, anyone who clones the repo gets the same agentic localization workflow for whichever layout you committed.

You can also pick a target explicitly:

```shell
lingua ai install --target claude   # Claude Code only
lingua ai install --target cursor   # Cursor only
lingua ai install --target agents   # .agents/skills only (often enough for any agent)
lingua ai install --target both     # Claude + Cursor
```

For a personal install across all projects on your machine, use `--global`. Each target has a global skills directory (`~/.claude/skills/`, `~/.cursor/skills/`, `~/.agents/skills/`):

```shell
lingua ai install --global                  # auto-detects from ~
lingua ai install --target cursor --global  # explicit
lingua ai install --target both --global    # Claude + Cursor global
lingua ai install --target agents --global  # ~/.agents/skills only
```

To inspect what's installed (reports all five target × scope combinations):

```shell
lingua ai status
```

To remove:

```shell
lingua ai uninstall                          # project scope, auto-detected targets
lingua ai uninstall --target cursor          # remove only Cursor skills (project)
lingua ai uninstall --global                 # remove global skills (auto-detected from ~)
lingua ai uninstall --target cursor --global # remove only Cursor global skills
```

The bundled skills are:

| Skill | What it does |
|---|---|
| `lingua-add-translation` | Add a new key to the sheet (section-aware) and regenerate platform files. |
| `lingua-update-translation` | Update an existing key's value(s) in place. |
| `lingua-find-key` | Search the sheet for an existing key/value before duplicating. |
| `lingua-regenerate` | Regenerate platform files after sheet edits. |
| `lingua-doctor` | Diagnose configuration / auth / sheet alignment problems. |

---

## 2. Configure write access (service account)

Reading the sheet only needs an API key. Writing to it (which is what `lingua add` and `lingua update` do) requires a Google **service account** because Google's API key auth is read-only.

1. Open [Google Cloud Console](https://console.cloud.google.com/) → IAM & Admin → Service Accounts → **Create service account**. Give it any name (e.g. `lingua-writer`).
2. After it's created, open it → **Keys** → **Add key** → **Create new key** → **JSON**. A JSON file is downloaded — keep it safe and **do not commit it to git**.
3. Open your localization Google Sheet → **Share** → paste the service account's email (looks like `lingua-writer@your-project.iam.gserviceaccount.com`) → give it **Editor** access.
4. Reference the JSON file in your `lingua_config.json`:

```json
{
  "localization": {
    "apiKey": "<google_api_key>",
    "sheetId": "<google_spreadsheet_id>",
    "outputDirectory": "path/to/Resources/Localization",
    "swiftCode": {
      "stringsDirectory": "path/to/Resources/Localization/en.lproj",
      "outputSwiftCodeFileDirectory": "path/to/Resources/Localization"
    },
    "serviceAccountKeyPath": "path/to/lingua-writer.json",
    "defaultWriteSheet": "en_US_English"
  }
}
```

`serviceAccountKeyPath` and `defaultWriteSheet` are both optional. Read commands keep working without them. `defaultWriteSheet` is the **canonical** tab whose row order Lingua uses when picking where to insert new rows; when omitted, Lingua picks the first English-prefixed tab.

Verify everything is wired up:

```shell
lingua doctor ./lingua_config.json
```

You should see all checks return `ok: true`.

---

## 3. The agent-facing subcommands

All new subcommands emit a stable JSON envelope on stdout (`{"ok": true, "data": {...}}`) and exit non-zero with a `{"ok": false, "error": {"code", "message", "details"}}` payload on stderr on failure. This contract is what makes them safe to drive from an LLM.

### `lingua sections <config>`

Lists every section in the canonical sheet with key counts, row ranges, and sample keys. **Always call this before `lingua add`** so the agent picks the right section.

```json
{
  "ok": true,
  "data": {
    "canonicalSheet": "en_US_English",
    "sections": [
      { "name": "welcome",    "keyCount": 4, "firstRow": 2, "lastRow": 5,  "sampleKeys": ["title", "subtitle", "cta", "footer"] },
      { "name": "onboarding", "keyCount": 3, "firstRow": 6, "lastRow": 8,  "sampleKeys": ["step_1", "step_2", "step_3"] }
    ]
  }
}
```

### `lingua list <config> [--section <name>]`

Dumps every translation row, optionally filtered to a single section.

### `lingua find <config> <query> [--limit N]`

Substring + simple-rank search across keys, sections, and English values. Used to avoid creating duplicate keys.

```json
{
  "ok": true,
  "data": {
    "query": "save",
    "matches": [
      { "section": "settings", "key": "save_changes", "row": 12, "englishValue": "Save changes", "score": 90, "matchedOn": "value" }
    ]
  }
}
```

### `lingua add <config> --section <s> --key <k> --value <lang>=<text> [--value ...] [--new-section] [--dry-run]`

Inserts a new row **inside the correct section's block** (not at the bottom of the sheet) in every language tab simultaneously. Languages you don't pass get blank cells so the tabs stay aligned.

Errors the agent must handle:

| Code | Meaning |
|---|---|
| `duplicate_key` | A row already exists for `(section, key)`. The agent should reuse it. |
| `unknown_section` | The section doesn't exist. `error.details.suggestions` lists the 3 closest matches. The agent must ask the user before passing `--new-section`. |
| `tabs_out_of_sync` | Language tabs have different `(section, key)` rows. Run `lingua doctor`. |
| `missing_service_account` | `serviceAccountKeyPath` not configured. |

Success payload:

```json
{
  "ok": true,
  "data": {
    "section": "onboarding",
    "key": "cta_start",
    "rowIndex": 9,
    "createdNewSection": false,
    "languagesWritten": ["en_US_English", "de_DE_German"],
    "languagesSkipped": ["fr_FR_French"],
    "dryRun": false
  }
}
```

### `lingua update <config> --section <s> --key <k> --value <lang>=<text> [--value ...]`

Updates the "Value Other" cell of an existing row in place. Only languages you pass are touched. Errors with `not_found` if the row doesn't exist.

### `lingua sync <config> --platform ios|android`

Equivalent to today's `lingua ios` / `lingua android`, but emits a JSON status payload.

### `lingua doctor <config>`

Runs a battery of checks: config completeness, output directory writability, service account loadability, sheet reachability, tab alignment. Exits non-zero if any check fails so CI / agents can detect a broken setup.

```json
{
  "ok": true,
  "data": {
    "checks": [
      { "name": "config.apiKey",          "ok": true,  "detail": "OK" },
      { "name": "config.sheetId",         "ok": true,  "detail": "OK" },
      { "name": "outputDirectory.writable","ok": true, "detail": "..." },
      { "name": "serviceAccount.load",    "ok": true,  "detail": "..." },
      { "name": "sheet.reachable",        "ok": true,  "detail": "3 language tabs" },
      { "name": "sheet.canonical",        "ok": true,  "detail": "en_US_English" },
      { "name": "tabs.aligned",           "ok": true,  "detail": "All tabs aligned" }
    ]
  }
}
```

---

## 4. Example agent transcript

> **User:** Add an empty-state string for the favorites screen: "No favorites yet."
>
> **Agent:** *runs `lingua find ./lingua_config.json "no favorites yet"`* — no matches.
> *runs `lingua sections ./lingua_config.json`* — sees `welcome`, `onboarding`, `favorites`, `settings`. Picks `favorites` because the file lives in `Features/Favorites/`.
> *runs `lingua add ./lingua_config.json --section favorites --key empty_state --value en="No favorites yet"`* — JSON returns `{rowIndex: 14, createdNewSection: false}`.
> *runs `lingua sync ./lingua_config.json --platform ios`*.
> *edits `FavoritesView.swift`* to use `Lingua.Favorites.empty_state`.

---

## 5. Section-aware insertion (the important detail)

The reason `lingua add` exists rather than just appending to the sheet: sections in the Google Sheet are **positionally meaningful**. A new key for `onboarding` should appear inside the `onboarding` block of rows so the sheet stays human-readable.

Lingua finds the last row whose section column matches `--section`, inserts a blank row at `lastRow + 1` in **every** language tab via `spreadsheets.batchUpdate` + `InsertDimension`, and then writes the section, key, and per-language values into the new row. If the language tabs are misaligned, Lingua aborts with `tabs_out_of_sync` rather than risk corrupting the sheet — `lingua doctor` will tell you which tabs are out of sync.

For brand new sections, Lingua appends to the bottom of the sheet (per language tab) and reports `createdNewSection: true`. The skill explicitly tells the agent to ask for user confirmation before passing `--new-section`.
