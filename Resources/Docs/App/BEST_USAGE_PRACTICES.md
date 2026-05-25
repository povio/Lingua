## Best Usage Practices

#### 1. Using Lingua Tool Locally

The configuration file contains the Google API key and the Google Spreadsheet ID, which should **NOT** be committed to the repository. To handle this securely, we provide a script to load these keys from a **.env** file. Here is the script:

`localization.sh`

```shell
#!/bin/bash

# Source the .env file to get the environment variables. Update the path
source ./../../.env

# JSON file path
JSON_FILE="./lingua_config.json"

# Backup original JSON file
cp $JSON_FILE "$JSON_FILE.bak"

# Update GOOGLE_API_KEY
sed -i '' "s|<google_api_key>|${GOOGLE_API_KEY}|g" $JSON_FILE

# Update GOOGLE_SPREADSHEET_ID
sed -i '' "s|<google_spreadsheet_id>|${GOOGLE_SPREADSHEET_ID}|g" $JSON_FILE

# Run the lingua command for `ios` or `android`
lingua ios ./lingua_config.json

# Restore the original JSON file
mv "$JSON_FILE.bak" $JSON_FILE
```

> **Note:** The `sed -i ''` syntax is macOS (BSD sed) specific. On Linux, use `sed -i` without the empty string argument.

Keep the configuration file with the values like this `<google_api_key>` and `<google_spreadsheet_id>` since the script will replace them by this pattern. Also define `GOOGLE_API_KEY` and `GOOGLE_SPREADSHEET_ID` with the values in your `.env` file. Make sure `.env` is listed in your `.gitignore` to avoid accidentally committing credentials.

Now simply run the script `sh localization.sh` every time new translations need to be imported.

In order to execute the shell script more conveniently, you may alter its permissions using the `chmod +x localization.sh` command. This will set the script to executable mode. Following this, you can execute the script directly using `./localization.sh`. 

#### 2. Using Lingua tool in CI/CD

For CI/CD usage, we have to handle the keys a bit differently. We created a shell script that injects the keys from secret variables (usually stored in the CI/CD environment).

This way, we avoid exposing sensitive keys, while still enabling our CI/CD pipeline to access the necessary resources for building and testing. The exact process of injecting the secret variables will depend on the specific CI/CD platform you're using.

Most CI/CD platforms offer a way to securely store sensitive information and inject them into the pipeline as environment variables. Make sure to consult the documentation for your CI/CD platform to understand the specific steps required.

`cicd_localization.sh`

```shell
#!/bin/bash

# JSON file path
JSON_FILE="./lingua_config.json"

# Backup original JSON file
cp $JSON_FILE "$JSON_FILE.bak"

# Update GOOGLE_API_KEY
sed -i '' "s|<google_api_key>|${GOOGLE_API_KEY}|g" $JSON_FILE

# Update GOOGLE_SPREADSHEET_ID
sed -i '' "s|<google_spreadsheet_id>|${GOOGLE_SPREADSHEET_ID}|g" $JSON_FILE

# Run the lingua command
lingua ios ./lingua_config.json

# Restore the original JSON file
mv "$JSON_FILE.bak" $JSON_FILE
```

> **Note:** The `sed -i ''` syntax is macOS (BSD sed) specific. On Linux CI runners, use `sed -i` without the empty string argument.

> **Security:** Avoid printing the substituted config file to CI logs (e.g. via `cat $JSON_FILE`) as it will expose your API key in plain text.
