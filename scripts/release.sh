#!/usr/bin/env bash
#
# release.sh — Tag a version, build & package the app, create a GitHub Release
# with the .zip asset, and print the exact values to update the Homebrew cask.
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - clean working tree (commit your changes first)
#
# Usage:
#   scripts/release.sh <version>        # e.g. scripts/release.sh 1.0.0
#
# Honors the same optional SIGN_IDENTITY / NOTARY_PROFILE env vars as build_release.sh.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: scripts/release.sh <version>   (e.g. 1.0.0)" >&2
  exit 1
fi
TAG="v$VERSION"

# --- Preconditions -----------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found. Install with: brew install gh" >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated. Run: gh auth login" >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree is dirty. Commit or stash changes before releasing." >&2
  git status --short
  exit 1
fi

REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "==> Repository: $REPO_SLUG"

# --- Build & package ---------------------------------------------------------
"$SCRIPT_DIR/build_release.sh" "$VERSION"

ZIP_PATH="$REPO_ROOT/dist/StandUp-$VERSION.zip"
SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

# --- Tag ---------------------------------------------------------------------
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "==> Tag $TAG already exists; reusing it."
else
  echo "==> Creating tag $TAG"
  git tag -a "$TAG" -m "StandUp $VERSION"
  git push origin "$TAG"
fi

# --- GitHub Release ----------------------------------------------------------
DOWNLOAD_URL="https://github.com/$REPO_SLUG/releases/download/$TAG/StandUp-$VERSION.zip"

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "==> Release $TAG exists; uploading/overwriting asset."
  gh release upload "$TAG" "$ZIP_PATH" --clobber
else
  echo "==> Creating GitHub Release $TAG"
  gh release create "$TAG" "$ZIP_PATH" \
    --title "StandUp $VERSION" \
    --notes "StandUp $VERSION

Install via Homebrew:
    brew tap matanganon/standup
    brew install --cask standup

Or download StandUp-$VERSION.zip below, unzip, and move StandUp.app to /Applications."
fi

# --- Cask update block -------------------------------------------------------
CASK_INFO="$REPO_ROOT/dist/cask-update-$VERSION.txt"
cat > "$CASK_INFO" <<EOF
Update your homebrew-standup tap's Casks/standup.rb with:

  version "$VERSION"
  sha256 "$SHA"
  url "$DOWNLOAD_URL"

Download URL : $DOWNLOAD_URL
SHA-256      : $SHA
EOF

echo ""
echo "============================================================"
echo " Released StandUp $VERSION → $REPO_SLUG ($TAG)"
echo "------------------------------------------------------------"
cat "$CASK_INFO"
echo "============================================================"
echo ""
echo "Next: update the cask in your homebrew-standup repo."
echo "If the tap lives next to this repo, you can run:"
echo "  scripts/update_cask.sh $VERSION ../homebrew-standup"
