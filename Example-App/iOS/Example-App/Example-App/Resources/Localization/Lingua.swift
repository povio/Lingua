// swiftlint:disable all
// This file was generated with Lingua command line tool. Please do not change it!
// Source: https://github.com/poviolabs/Lingua

import Foundation

public enum Lingua {
	public enum General {
		/// Save
		public static let save = tr("General", "save")
		/// Success
		public static let success = tr("General", "success")
	}
    
	private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
		let format = normalizedPrintfFormat(BundleToken.bundle.localizedString(forKey: key, value: nil, table: table))
		return String(format: format, locale: Locale.current, arguments: args)
	}

	/// Maps full-width `％@` (U+FF05 + `@`) to ASCII `%@` so `String(format:)` substitutes arguments in zh-Hant copy.
	private static func normalizedPrintfFormat(_ format: String) -> String {
		format.replacingOccurrences(of: "\u{FF05}@", with: "%@")
	}
}

private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}

// swiftlint:enable all
