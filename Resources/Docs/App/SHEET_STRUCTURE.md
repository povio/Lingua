# Sheet Structure for Lingua Localization Tool

The Lingua localization tool utilizes a structured Google Sheets document to manage and store localization keys and values for various languages and platforms. Here's a detailed guide on how to structure the sheet.

## Language Sheets

For every language you wish to support, create an individual sheet within the Google Sheets document. Name the sheet using the convention `LanguageCode_LanguageName`. For example:

- `en_US_English`
- `fr_FR_French`
- `es_ES_Spanish`

## Columns Structure

The sheet will have several columns to manage different aspects of localization:

### Section

Identifier for referencing a group of keys

### Key

A unique identifier for referencing translation values in the code.

### Description

A brief description to help understand the context and usage of the localization key.

### Value columns

These columns store the translation values for different plural cases, following the [Unicode CLDR language plural rules](https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html). Below are the specific columns:

- **Value Zero**: Translation for zero quantity (if applicable)
- **Value One**: Translation for singular quantity
- **Value Two**: Translation for dual form (if applicable)
- **Value Few**: Translation for a few quantity (if applicable)
- **Value Many**: Translation for many quantity (if applicable)
- **Value Other**: Translation for all other quantities (if applicable)

## Section and Key Structure

To enhance the semantic organization of the localization keys, the Lingua tool supports the use of sections. Keys within the same section are grouped together, enabling a more intuitive and structured way to manage translations.

### Sheet Columns

- **Section**: This column is used to define the logical grouping of keys within a particular context or theme. Examples might include sections like "welcome," "error_messages," "settings," etc.
- **Key**: This column represents the specific localization key within a section. Combined with the section, it provides a unique identifier for each translation.

### Usage in Code

When localization files are generated, the section and key are combined to create platform-specific references:

#### For iOS:

The format will be `Lingua.Section.Key`. Using the example values mentioned:

- **Section**: `welcome`
- **Key**: `message`

The reference in iOS will be `Lingua.Welcome.message`.

#### For Android:

The format will be `R.string.section_key`. Using the example values:

- **Section**: `welcome`
- **Key**: `message`

The reference in Android will be `R.string.welcome_message`.

## String Format Specifiers

The Lingua localization tool uses [iOS (Apple) format specifiers](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Strings/Articles/formatSpecifiers.html) as the base for managing string replacements within localization keys. During the export process, these specifiers are automatically mapped to the corresponding iOS and Android platforms.

### Usage

You can add string format specifiers directly in your Google Sheets document using the standard iOS format. The tool will take care of mapping them to each platform during the export process.

Here are the common iOS format specifiers used:

- `%@`: Placeholder for strings
- `%d`: Placeholder for integers
- `%f`: Placeholder for floating-point numbers

### Examples

- Localization Key: `welcome_message`
  - **Exported English (iOS)**: `Welcome %@!`
  - **Exported English (Android)**: `Welcome, %1$s!`
  - **Exported German (iOS)**: `Willkommen %@!`
  - **Exported German (Android)**: `Willkommen, %1$s!`

In these examples, `%@` is used as a placeholder for the name of the user, a string value. During the export process, the iOS format specifier will remain the same for iOS and will be replaced with the appropriate Android placeholder.

On Android, the `1$` in `%1$s` is a positional index indicating which argument to use (1-based). For strings with multiple placeholders, each gets its own index: `%1$s`, `%2$s`, etc. This allows Android to reorder arguments in translations where word order differs between languages.

> **Plural columns:** Not all plural form columns need to be filled for every language. Only the forms applicable to a given language are required. For example, English only uses `one` and `other`; you can leave `zero`, `two`, `few`, and `many` blank for English entries.
