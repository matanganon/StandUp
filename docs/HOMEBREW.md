# Distributing StandUp via Homebrew

StandUp is distributed as a personal **Homebrew tap** (cask). Users install it with:

```bash
brew tap matanganon/standup
brew install --cask standup
```

This document covers the one-time tap setup and the per-release flow.

- Source code + release `.zip` assets live in the existing public repo: `matanganon/StandUp`.
- The cask lives in a separate tap repo: `matanganon/homebrew-standup`.
- The official `homebrew-cask` repository is **not** targeted yet.

---

## One-time: create the tap repository

A Homebrew tap is just a GitHub repo named `homebrew-<tapname>`. For `brew tap matanganon/standup`, the repo must be named **`homebrew-standup`**.

```bash
# Create the tap repo on GitHub (public) and clone it next to this project:
cd ..
gh repo create matanganon/homebrew-standup --public --clone
cd homebrew-standup
mkdir -p Casks
cp ../timer/homebrew/standup.rb Casks/standup.rb
git add Casks/standup.rb
git commit -m "Add StandUp cask"
git push
```

That's it — the tap is live. Nothing needs Homebrew's approval for a personal tap.

---

## Per-release flow (automated)

### Option A — GitHub Actions (recommended)

Pushing a version tag triggers `.github/workflows/release.yml`, which builds, packages, and publishes the GitHub Release automatically:

```bash
git tag -a v1.0.0 -m "StandUp 1.0.0"
git push origin v1.0.0
```

After the workflow finishes, grab the SHA-256 from the release notes (or the Actions log) and update the tap:

```bash
# From the StandUp project root, with dist/ populated — or just edit the cask by hand:
#   version "1.0.0"
#   sha256  "<sha from the release>"
```

### Option B — Local, one command

From the StandUp project root (clean git tree, `gh` authenticated):

```bash
scripts/release.sh 1.0.0
```

This will:
1. Build Release and package `dist/StandUp-1.0.0.zip`.
2. Compute the SHA-256.
3. Create tag `v1.0.0` and push it.
4. Create the GitHub Release with the zip attached.
5. Write `dist/cask-update-1.0.0.txt` with the exact `version`/`sha256`/`url` to use.

Then update the tap's cask automatically (if the tap is cloned next door):

```bash
scripts/update_cask.sh 1.0.0 ../homebrew-standup
```

This patches `Casks/standup.rb`, commits, and pushes the tap.

---

## Signing & notarization (optional)

The current development workflow produces **unsigned** builds. Unsigned apps are
blocked by Gatekeeper on first launch; the cask's `postflight` removes the
quarantine attribute so it opens anyway. This is fine for development/personal use.

To ship signed + notarized builds (recommended once you have an Apple Developer
account), set these before running the release:

```bash
# One-time: store notary credentials in the keychain.
xcrun notarytool store-credentials "standup-notary" \
    --apple-id "you@example.com" --team-id "YOURTEAMID" \
    --password "app-specific-password"

# Per release:
export SIGN_IDENTITY="Developer ID Application: Your Name (YOURTEAMID)"
export NOTARY_PROFILE="standup-notary"
scripts/release.sh 1.0.0
```

For GitHub Actions, add these repository secrets (the workflow uses them if present,
and falls back to unsigned otherwise):

| Secret | Purpose |
| --- | --- |
| `MACOS_CERT_P12_BASE64` | base64 of your Developer ID Application `.p12` |
| `MACOS_CERT_PASSWORD` | password for that `.p12` |
| `MACOS_SIGN_IDENTITY` | `Developer ID Application: Name (TEAMID)` |
| `NOTARY_APPLE_ID` | Apple ID email |
| `NOTARY_TEAM_ID` | Developer Team ID |
| `NOTARY_PASSWORD` | app-specific password |

Once releases are notarized, remove the `postflight`/quarantine block from the cask.

---

## Build locally without releasing

To just build and inspect the packaged app + SHA-256 without tagging or uploading:

```bash
scripts/build_release.sh 1.0.0
# → dist/StandUp-1.0.0.zip  and  dist/StandUp-1.0.0.zip.sha256
```
