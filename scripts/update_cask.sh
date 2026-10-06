#!/usr/bin/env bash
#
# update_cask.sh — Patch the version, sha256, and url in a homebrew tap's cask
# after a release, then commit & push the tap.
#
# Usage:
#   scripts/update_cask.sh <version> <path-to-homebrew-tap-repo>
#
# Example:
#   scripts/update_cask.sh 1.0.0 ../homebrew-standup
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-}"
TAP_DIR="${2:-}"
if [[ -z "$VERSION" || -z "$TAP_DIR" ]]; then
  echo "Usage: scripts/update_cask.sh <version> <path-to-tap-repo>" >&2
  exit 1
fi

ZIP_PATH="$REPO_ROOT/dist/StandUp-$VERSION.zip"
if [[ ! -f "$ZIP_PATH" ]]; then
  echo "ERROR: $ZIP_PATH not found. Run scripts/release.sh $VERSION first." >&2
  exit 1
fi
SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

CASK="$TAP_DIR/Casks/standup.rb"
if [[ ! -f "$CASK" ]]; then
  echo "ERROR: $CASK not found. Create the tap first (see docs/HOMEBREW.md)." >&2
  exit 1
fi

echo "==> Updating $CASK → version $VERSION, sha256 $SHA"
# Replace the version and sha256 lines in place.
/usr/bin/sed -i '' -E "s/^(  version )\"[^\"]*\"/\1\"$VERSION\"/" "$CASK"
/usr/bin/sed -i '' -E "s/^(  sha256 )\"[^\"]*\"/\1\"$SHA\"/" "$CASK"

( cd "$TAP_DIR"
  git add Casks/standup.rb
  git commit -m "standup $VERSION"
  git push
)
echo "==> Tap updated and pushed."
