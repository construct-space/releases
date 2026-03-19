# Construct Releases

This repo handles CI/CD releases for the Construct desktop app (Tauri).

## Releasing

Use the release script to trigger a build:

```bash
./release.sh <version> [branch]
# Example: ./release.sh 0.2.5
# Example: ./release.sh 0.2.5 feature-branch
```

Do NOT run `gh workflow run` manually — always use `release.sh`.

## Signing

- Tauri updater signing key: `~/.tauri/construct.key` (password: `construct`)
- GitHub secrets on `construct-space/releases`: `TAURI_SIGNING_PRIVATE_KEY`, `TAURI_SIGNING_PRIVATE_KEY_PASSWORD`
- Apple codesigning via keychain import in CI (Developer ID Application: Basecode shpk)
