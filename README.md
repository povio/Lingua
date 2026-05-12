<p align="center">
    <a href="Resources/Docs/README.md">
      <img src="Resources/Images/Lingua.png" width="50%" alt="Lingua" />
    </a>
</p>
<p align="center">
    <a href="Resources/Docs/README.md">
        <img src="http://img.shields.io/badge/read_the-docs-2196f3.svg" alt="Documentation">
    </a>
    <a href="https://www.swift.org" alt="Swift">
        <img src="https://img.shields.io/badge/Swift-5.7-orange.svg" />
    </a>
    <a href="./LICENSE" alt="License">
        <img src="https://img.shields.io/badge/Licence-MIT-green.svg" />
    </a>
    <a href="https://github.com/poviolabs/Lingua/actions/workflows/tests.yml" alt="Tests Status">
        <img src="https://github.com/poviolabs/Lingua/actions/workflows/tests.yml/badge.svg" />
    </a>
</p>

# Lingua

Lingua is a tool designed to streamline the localization process for iOS and Android platforms.
It provides a unified solution for generating localization files from a single source, Google Sheets.

There are several benefits of using the tool:

- Unified translation system for iOS and Android platforms

- Seamless integration with project workflows for automatic translation imports

- Minimized risk of typo errors in localization usage

- Enhanced productivity through intelligent auto-completion and semantic clarity

- Safeguard against referencing non-existent translations

## Setup Google Sheet

In order to setup Google sheet, we need to complete two steps. First one is to create a sheet with predefined structure, and the second one is to obtain api key and sheet id.

### a. Sheet Document

We have prepared a tamplate for sheet structure for you. What you have to do is to open the link below and make a copy `File > Make a copy`

[Mobile Localizations Template - Google Sheets](https://docs.google.com/spreadsheets/d/1Cnqy4gZqh9pGcTF_0jb8QGOnysejZ8dVfSj8dgX4kzM)

**Sheet structure**: For detailed information about the sheet structure used in the Lingua localization tool, please refer to the [Sheet Structure Documentation](Resources/Docs/App/SHEET_STRUCTURE.md).

**Important:** Make sure to replace the existing API key in your application with the newly generated one. Also, ensure that the Google Sheet you're trying to access has its sharing settings configured to allow access to anyone with the link. You can do this by clicking on "Share" in the upper right corner of the Google Sheet and selecting "Anyone with the link."

### b. Obtain the sheet id

The sheet id can easly be accessed from the url after you have create a copy of the document tamplate.

`https://docs.google.com/spreadsheets/d/` ***`1GpaPpO4JMleZPd8paSW4qPBQxjImm2xD8yJhvZOP-8w`***

### c. Obtain the API key

Here are the steps to enable the Google Sheets API and create an API key:

1. Go to the [https://console.cloud.google.com/](https://console.cloud.google.com/).

2. If you haven't already, create a new project or select an existing one.

3. In the left sidebar, click on "APIs & Services"

4. Click on "+ ENABLE APIS AND SERVICES" at the top of the page.

5. In the search bar, type "Google Sheets API" and select it from the list.

6. Click on "ENABLE" to enable the Google Sheets API for your project.

7. After the API is enabled, go back to the "APIs & Services" > "Credendtials" page.

8. Click on "CREATE CREDENTIALS" at the top of the page.

9. In the dropdown, select "API key"

Wait a bit until the key is generated and an information modal with the message `API key created` will be shown.

## Usage

### 1. macOS App

The Lingua macOS app provides a user-friendly interface for managing your localization process seamlessly. You can configure your settings and initiate the translation process directly from the app.

#### Installation

You can download the macOS app from [App Store](https://apps.apple.com/us/app/lingua-tool/id6463116155). Follow the installation guide available on the page to get started with the app.

#### Features and Usage

- **Settings Configuration:** Easily configure and manage your settings through the app's settings panel.
- **Translation Initiation:** Initiate the translation process with a single click without the need for terminal commands.
- **AI Agent Skills:** Install Lingua's bundled Agent Skills for Claude Code, Cursor, or `.agents/` directly into your project's root from the **Lingua AI** section of the project form — no terminal required.

### 2. macOS Terminal App

For those who prefer using the terminal or require scriptable solutions, Lingua offers a terminal app that allows you to manage and initiate translations directly from the command line.

#### Installation

Currently we support the tool to be installed via Homebrew

```shell
$ brew tap poviolabs/lingua
$ brew install lingua
```

### 3. Linux Terminal App

Lingua runs on Linux as well.

#### Installation

1. Download the latest release `Lingua_Linux` from [GitHub Releases](https://github.com/poviolabs/Lingua/releases) based on your machine, either `Lingua_Linux_x86_64` or `Lingua_Linux_arm64`

2. Make the binary executable:
   
   ```shell
   $ chmod +x /path/to/Lingua_Linux_x86_64
   $ mv Lingua_Linux lingua
   $ sudo mv /path/to/lingua /usr/local/bin
   ```

### Terminal Usage

Please follow below instructions to use Lingua in terminal.

##### Configuration file

Create a configuration file as a starting point to adapt as your needs, `lingua_config.json` or any other `.json` file.

To create a sample configuration file as a starting point to adapt to your needs, run `lingua config init`. The tool will create a file named `lingua_config.json` in the directory you are running the Lingua tool.

Then in the configuration file created you need to provide your data, like below:

```json
{
   "localization": {
        "apiKey": "<google_api_key>",
        "sheetId": "<google_spreadsheet_id>",
        "outputDirectory": "path/to/Resources/Localization"
    }
}
```

##### Output directory

The output directory property should be the path where you want the tool to create localization files. 

* For iOS it can be any directory on your project. 

  After you run the command, for the first time, you have to **`Add files to 'YourProject'`** in Xcode.\
  **NOTE:** If you are using Xcode 16 and have structured your project using **Folders** instead of **Groups**, this step is not necessary.

* For Android, since the translation are placed in a specific project directory, the output directory it should look something like this: **`path/YourProject/app/src/main/res `**

##### iOS specific

Since iOS does not have a built in feature to access the localization safely, we have made this possible using Lingua tool. In the configuration file you have to provide the path where the default language strings are stored and where the Swift file you want to be created. With that the tool will create **Lingua.swift** with an enumeration to easily access localizations in your app.

```json
{
   "localization": {
        "apiKey": "<google_api_key>",
        "sheetId": "<google_spreadsheet_id>",
        "outputDirectory": "path/to/Resources/Localization",
        "swiftCode": {
           "stringsDirectory": "path/to/Resources/Localization/en.lproj",
           "outputSwiftCodeFileDirectory": "path/to/Resources/Localization"
        }
    }
}
```

Now you can run the tool in terminal, switch to your project directory and run:

**iOS**

```shell
$ lingua ios /path/to/lingua_config.json
```

**Android**

```shell
$ lingua android /path/to/lingua_config.json
```

**Best Usage Practices**

To ensure you're leveraging the tool optimally, both locally and in the context of CICD, we recommend you delve into our [Best Usage Practices guide](./Resources/Docs/App/BEST_USAGE_PRACTICES.md).

## Using Lingua with an AI coding agent

Lingua ships with bundled [Agent Skills](https://agentskills.io/) for [Claude Code](https://docs.claude.com/claude-code), [Cursor](https://cursor.com/docs/skills) (2.4+), and a generic `.agents/skills/` layout, so an AI agent can drive the whole localization loop end-to-end — discover existing keys, add new translations directly to your Google Sheet, regenerate platform files, and reference the new key in your Swift / Kotlin code.

```shell
$ cd MyAwesomeApp
$ lingua ai install        # auto-detects from the repo root resolved from cwd
$ git add .claude .cursor .agents  # commit whichever was written
```

`lingua ai install` walks up from the current directory to find the project root by looking for `.git`, `.claude`, `.cursor`, or `.agents`, then auto-detects which integration(s) to install there. Use `--target claude|cursor|agents|both` to choose explicitly (`both` = Claude + Cursor only; prefer `--target agents` when a shared `.agents/skills/` tree is enough), and `--global` to install under `~/.claude/skills/`, `~/.cursor/skills/`, or `~/.agents/skills/` instead.

Once installed, you can talk to your agent naturally — *"add an empty-state string for the favorites screen: 'No favorites yet'"* — and it will run `lingua find`, `lingua sections`, `lingua add`, `lingua sync`, and edit your view to use the new key.

Prefer a GUI? The macOS Lingua app exposes the same installer under the **Lingua AI** section of the project form — pick a target, click Install, and grant the one-time folder-access prompt; see [AI agent usage guide](./Resources/Docs/App/AI_AGENT_USAGE.md) for details.

The new agent-facing subcommands (`lingua sections`, `lingua list`, `lingua find`, `lingua add`, `lingua update`, `lingua sync`, `lingua doctor`) all emit a stable JSON envelope and are fully scriptable, so you can also wire them into other AI frameworks or CI jobs. See [AI agent integration plan](./Resources/Docs/App/AI_AGENT_INTEGRATION.md) and [AI agent usage guide](./Resources/Docs/App/AI_AGENT_USAGE.md) for details, including how to set up a Google service account for write access.

