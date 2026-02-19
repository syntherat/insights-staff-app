# insights-staff-app

## Android APK auto-release (GitHub Actions)

This repository includes a workflow at `.github/workflows/release-apk.yml` that:
- builds the Flutter Android release APK,
- uploads it as a workflow artifact,
- publishes it to GitHub Releases automatically.

### Triggers
- Push to `main` → creates a prerelease with tag `build-<run_number>`.
- Push tag `v*` (example: `v1.2.0`) → creates a normal release for that tag.
- Manual `workflow_dispatch` is also supported.

### Required repository secrets
Set these in GitHub: **Settings → Secrets and variables → Actions**

- `ANDROID_KEYSTORE_BASE64` (base64 content of your release `.jks`)
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`
