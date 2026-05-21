# Releasing Lingua CLI

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

## Version format

Use [semantic versioning](https://semver.org): `vMAJOR.MINOR.PATCH` (e.g. `v1.2.3`).

## Prerequisites (one-time setup)

The workflow requires a repository secret named `HOMEBREW_TAP_TOKEN`:

1. Go to your GitHub profile → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.
2. Set **Resource owner** to `povio`, **Repository access** to *Only select repositories* → `povio/homebrew-lingua`, and under **Permissions** grant **Contents: Read and Write** only.
3. Add it to this repo: `github.com/povio/Lingua` → **Settings** → **Secrets and variables** → **Actions** → **New repository secret** → name it `HOMEBREW_TAP_TOKEN`.

This only needs to be done once per repo (or when the token expires).
