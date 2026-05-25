# Releasing Lingua

## CLI (GitHub Actions)

Releases are fully automated via GitHub Actions. To cut a new release:

1. Make sure all changes are merged to `main`.
2. Push a version tag:
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```

That's it. The [release workflow](.github/workflows/release.yml) will:
- Build a Universal Binary (arm64 + x86_64)
- Create a GitHub Release and attach the binary
- Update the Homebrew formula in [povio/homebrew-lingua](https://github.com/povio/homebrew-lingua)

## macOS App (Xcode Cloud)

The macOS app is distributed via Xcode Cloud. To trigger a release:

1. Make sure all changes are merged to `main`.
2. Push a version tag with the `app/v` prefix:
   ```bash
   git tag app/v1.2.3
   git push origin app/v1.2.3
   ```

Xcode Cloud will:
- Archive the macOS app
- Distribute to TestFlight (Internal Testing)

## Version format

Both use [semantic versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

| Target     | Tag format      | Example       |
|------------|-----------------|---------------|
| CLI        | `v1.2.3`        | `v1.1.1`      |
| macOS App  | `app/v1.2.3`    | `app/v1.1.1`  |

## Prerequisites (one-time setup)

The workflow requires a repository secret named `HOMEBREW_TAP_TOKEN`:

1. Go to your GitHub profile → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.
2. Set **Resource owner** to `povio`, **Repository access** to *Only select repositories* → `povio/homebrew-lingua`, and under **Permissions** grant **Contents: Read and Write** only.
3. Add it to this repo: `github.com/povio/Lingua` → **Settings** → **Secrets and variables** → **Actions** → **New repository secret** → name it `HOMEBREW_TAP_TOKEN`.

This only needs to be done once per repo (or when the token expires).
