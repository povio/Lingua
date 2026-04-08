import Foundation

enum HelpText {
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
    lingua find     <config.json> <query>  Search keys/sections/values
    lingua add      <config.json> --section <s> --key <k> --value <lang>[:form]=<text> [--value ...]
                                           [--new-section] [--dry-run]
                                           Insert a new row inside the right section.
                                           --value en="Save"          (auto-picks plural column)
                                           --value en:one="1 item" --value en:other="%d items"
    lingua update   <config.json> --section <s> --key <k> --value <lang>[:form]=<text> [--value ...]
                                           Update an existing row's values in place
    lingua delete   <config.json> --section <s> --key <k>
                                           Delete a row across all language tabs (recovery tool)
    lingua doctor   <config.json>          Verify config / auth / sheet alignment

  CONFIG SCAFFOLD
    lingua config init                     Generate a template lingua_config.json

  AI INTEGRATION
    lingua ai install [--global] [--force] Install bundled Claude Code skills
    lingua ai uninstall [--global]         Remove installed skills
    lingua ai status                       Show what's installed and where

  OTHER
    lingua help, --help, -h                Show this help
    lingua -v, --version                   Show Lingua version

  See https://github.com/poviolabs/Lingua for full docs.
  """
}
