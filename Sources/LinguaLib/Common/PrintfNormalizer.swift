import Foundation

/// Rewrites full-width `％` (U+FF05) printf specifiers (e.g. `％@`, `％d`, `％1$@`, `％.2f`) to ASCII `%`.
///
/// Applied once to every translation value as it leaves the Google Sheet, so downstream iOS
/// (`.strings`, `.stringsdict`, generated `Lingua.swift`) and Android (`strings.xml`) artifacts
/// only ever contain ASCII printf specifiers that `String(format:)` / `String.format` recognize.
/// Plain `％` without a trailing specifier (e.g. Japanese `85％`) is left untouched.
enum PrintfNormalizer {
  private static let pattern = #"\uFF05((?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(?:hh|h|ll|l|L|z|j|t|q)?[@dDiouxXfFeEgGaAcCsSp%])"#
  private static let regex = try! NSRegularExpression(pattern: pattern)

  static func normalize(_ value: String) -> String {
    guard value.contains("\u{FF05}") else { return value }
    let range = NSRange(value.startIndex..., in: value)
    return regex.stringByReplacingMatches(in: value, range: range, withTemplate: "%$1")
  }
}
