// swiftlint:disable all
// This file was generated with Lingua command line tool. Please do not change it!
// Source: https://github.com/poviolabs/Lingua

import Foundation

public enum Lingua {
	public enum App {
		/// About Lingua
		public static let about = tr("App", "about")
		/// Copyright
		public static let copyright = tr("App", "copyright")
		/// © 2023 Povio Inc.
		public static let copyrightYear = tr("App", "copyright_year")
		/// A unified localization management tool for iOS & Android
		public static let description = tr("App", "description")
		/// Lingua Settings...
		public static let settings = tr("App", "settings")
	}

	public enum General {
		/// Choose
		public static let choose = tr("General", "choose")
		/// Delete
		public static let delete = tr("General", "delete")
		/// Duplicate
		public static let duplicate = tr("General", "duplicate")
		/// Error
		public static let error = tr("General", "error")
		/// Save
		public static let save = tr("General", "save")
		/// Search
		public static let search = tr("General", "search")
		/// Success
		public static let success = tr("General", "success")
		/// this
		public static let this = tr("General", "this")
	}

	public enum ProjectForm {
		/// Here are the steps to enable the Google Sheets API and create an API key:\n\n* Go to the https://console.cloud.google.com/.\n* If you haven't already, create a new project or select an existing one.\n* In the left sidebar, click on "APIs & Services"\n* Click on "+ ENABLE APIS AND SERVICES" at the top of the page.\n* In the search bar, type "Google Sheets API" and select it from the list.\n* Click on "ENABLE" to enable the Google Sheets API for your project.\n* After the API is enabled, go back to the "APIs & Services" > "Credendtials" page.\n* Click on "CREATE CREDENTIALS" at the top of the page.\n* In the dropdown, select "API key"\n* Wait a bit until the key is generated and an information modal with the message API key created will be shown.
		public static let apiKeyHelp = tr("ProjectForm", "api_key_help")
		/// Configuration
		public static let configurationSection = tr("ProjectForm", "configuration_section")
		/// Copied to clipboard!
		public static let copiedToClipboard = tr("ProjectForm", "copied_to_clipboard")
		/// Check the current Lingua AI setup for this project and install or remove agent skills in the selected target.
		public static let linguaAiDescription = tr("ProjectForm", "lingua_ai_description")
		/// Lingua could not access the selected project directory.
		public static let linguaAiDirectoryAccessError = tr("ProjectForm", "lingua_ai_directory_access_error")
		/// Checking...
		public static let linguaAiCheckingStatus = tr("ProjectForm", "lingua_ai_checking_status")
		/// Install Lingua AI
		public static let linguaAiInstallButton = tr("ProjectForm", "lingua_ai_install_button")
		/// Lingua AI installed for %@.
		public static func linguaAiInstalled(_ param1: String) -> String {
			return tr("ProjectForm", "lingua_ai_installed", param1)
		}
		/// Installed
		public static let linguaAiInstalledStatus = tr("ProjectForm", "lingua_ai_installed_status")
		/// Installed targets: %@
		public static func linguaAiInstalledTargets(_ param1: String) -> String {
			return tr("ProjectForm", "lingua_ai_installed_targets", param1)
		}
		/// Installing Lingua AI...
		public static let linguaAiInstalling = tr("ProjectForm", "lingua_ai_installing")
		/// Select an output directory before using Lingua AI.
		public static let linguaAiMissingDirectoryError = tr("ProjectForm", "lingua_ai_missing_directory_error")
		/// Choose an output directory to use Lingua AI for this project.
		public static let linguaAiNeedsDirectory = tr("ProjectForm", "lingua_ai_needs_directory")
		/// No Lingua AI tools are installed for this project.
		public static let linguaAiNoInstalledTargetsError = tr("ProjectForm", "lingua_ai_no_installed_targets_error")
		/// No Lingua AI targets are installed in this project.
		public static let linguaAiNoTargetsInstalled = tr("ProjectForm", "lingua_ai_no_targets_installed")
		/// Not installed
		public static let linguaAiNotInstalled = tr("ProjectForm", "lingua_ai_not_installed")
		/// Partially installed
		public static let linguaAiPartiallyInstalled = tr("ProjectForm", "lingua_ai_partially_installed")
		/// Lingua AI
		public static let linguaAiSection = tr("ProjectForm", "lingua_ai_section")
		/// Uninstall Lingua AI
		public static let linguaAiUninstallButton = tr("ProjectForm", "lingua_ai_uninstall_button")
		/// Lingua AI uninstalled.
		public static let linguaAiUninstalled = tr("ProjectForm", "lingua_ai_uninstalled")
		/// Uninstalling Lingua AI...
		public static let linguaAiUninstalling = tr("ProjectForm", "lingua_ai_uninstalling")
		/// Status
		public static let linguaAiStatusTitle = tr("ProjectForm", "lingua_ai_status_title")
		/// Unavailable
		public static let linguaAiStatusUnavailable = tr("ProjectForm", "lingua_ai_status_unavailable")
		/// Install target
		public static let linguaAiTargetPicker = tr("ProjectForm", "lingua_ai_target_picker")
		/// Add section
		public static let filteringAddSectionButtonTitle = tr("ProjectForm", "filtering_add_section_button_title")
		/// Add the sections that you want to include into the project, otherwise if it is disabled all the sections will be included
		public static let filteringSectionDescription = tr("ProjectForm", "filtering_section_description")
		/// Enter a section
		public static let filteringSectionTextfieldPlaceholder = tr("ProjectForm", "filtering_section_textfield_placeholder")
		/// Enable sections filtering
		public static let filteringSectionTitle = tr("ProjectForm", "filtering_section_title")
		/// Info
		public static let infoHeader = tr("ProjectForm", "info_header")
		/// API Key *
		public static let inputApiKey = tr("ProjectForm", "input_api_key")
		/// Choose Directory
		public static let inputDirectoryButton = tr("ProjectForm", "input_directory_button")
		/// Output directory *
		public static let inputDirectoryOutput = tr("ProjectForm", "input_directory_output")
		/// Show in Finder
		public static let openInFinder = tr("ProjectForm", "open_in_finder")
		/// Name *
		public static let inputProjectName = tr("ProjectForm", "input_project_name")
		/// Sheet ID *
		public static let inputSheetId = tr("ProjectForm", "input_sheet_id")
		/// After you "Localize", you have to Add files to "%@"... in Xcode, if they are not added already.\n\nNOTE: If you are using Xcode 16 and have structured your project using 'Folders' instead of 'Groups', this step is not necessary.
		public static func iosLocalizationInfoMessage(_ param1: String) -> String {
			return tr("ProjectForm", "ios_localization_info_message", param1)
		}
		/// Last localized: %@
		public static func lastLocalizedSubtitle(_ param1: String) -> String {
			return tr("ProjectForm", "last_localized_subtitle", param1)
		}
		/// Lingua.swift Directory *
		public static let linguaSwiftOutputDirectory = tr("ProjectForm", "lingua_swift_output_directory")
		/// This should be the directory where you want to store the generated Lingua.swift file
		public static let linguaSwiftOutputDirectoryHelp = tr("ProjectForm", "lingua_swift_output_directory_help")
		/// Localize
		public static let localizeButton = tr("ProjectForm", "localize_button")
		/// The .lproj directory should be the directory where .strings files are saved.\nIt serves as base language directory from where the Lingua.swift file will be created
		public static let lprojDirectoryHelp = tr("ProjectForm", "lproj_directory_help")
		/// The output directory property should be the path where you want the tool to create localization files.\n\n* For iOS it can be any directory on your project. After you run the command, for the first time, \n   you have to Add files to 'YourProject' in Xcode.\n\n* For Android, since the translation are placed in a specific project directory,\n   the output directory it should look something like this: path/YourProject/app/src/main/res 
		public static let outputDirectoryHelp = tr("ProjectForm", "output_directory_help")
		/// Platform *
		public static let platformPickerTitle = tr("ProjectForm", "platform_picker_title")
		/// * Make a copy of the [Sheet Template](https://docs.google.com/spreadsheets/d/1Cnqy4gZqh9pGcTF_0jb8QGOnysejZ8dVfSj8dgX4kzM) from menu "File > Make a copy"\n* Ensure that the Google Sheet you're trying to access has its sharing settings configured to allow access to anyone with the link.\n   You can do this by clicking on "Share" in the upper right corner of the Google Sheet and selecting "Anyone with the link."\n* The sheet id can easly be accessed from the url after you have create a copy of the document tamplate.\n\nExample:\n\nhttps://docs.google.com/spreadsheets/d/ 1GpaPpO4JMleZPd8paSW4qPBQxjImm2xD8yJhvZOP-8w
		public static let sheetIdHelp = tr("ProjectForm", "sheet_id_help")
		/// .lproj Directory *
		public static let stringsDirectory = tr("ProjectForm", "strings_directory")
		/// Since iOS does not have a built in feature to access the localization safely, we have made this possible using Lingua tool. Below you have to provide the path where the Swift file you want to be created. With that the tool will create Lingua.swift with an enumeration to easily access localizations in your app.
		public static let swiftCodeDescription = tr("ProjectForm", "swift_code_description")
		/// iOS Swift Code Settings
		public static let swiftCodeSection = tr("ProjectForm", "swift_code_section")
		/// Generate Swift Code
		public static let swiftCodeToggleTitle = tr("ProjectForm", "swift_code_toggle_title")
	}

	public enum ProjectMenu {
		/// Delete
		public static let delete = tr("ProjectMenu", "delete")
		/// Duplicate
		public static let duplicate = tr("ProjectMenu", "duplicate")
		/// Localize
		public static let localize = tr("ProjectMenu", "localize")
		/// New
		public static let new = tr("ProjectMenu", "new")
		/// Project
		public static let title = tr("ProjectMenu", "title")
	}

	public enum Projects {
		/// %@ copy
		public static func copyProject(_ param1: String) -> String {
			return tr("Projects", "copy_project", param1)
		}
		/// Are you sure you want to delete "%@" project?
		public static func deleteAlertMessage(_ param1: String) -> String {
			return tr("Projects", "delete_alert_message", param1)
		}
		/// Confirmation
		public static let deleteAlertTitle = tr("Projects", "delete_alert_title")
		/// Projects
		public static let listSectionHeader = tr("Projects", "list_section_header")
		/// "%@" has been successfully localized.
		public static func localizedMessage(_ param1: String) -> String {
			return tr("Projects", "localized_message", param1)
		}
		/// Localizing...
		public static let localizing = tr("Projects", "localizing")
		/// New project
		public static let newProject = tr("Projects", "new_project")
		/// Select a project or add a new one.
		public static let placeholder = tr("Projects", "placeholder")
	}
    
	private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
		let format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
		return String(format: format, locale: Locale.current, arguments: args)
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
