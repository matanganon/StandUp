#!/usr/bin/env bash
#
# build_release.sh — Build, (optionally) sign & notarize, and package StandUp.app
# into a distributable .zip, then print the SHA-256 needed for the Homebrew cask.
#
# Works with NO credentials (produces an unsigned development build) and with
# credentials (produces a signed + notarized build).
#
# Usage:
#   scripts/build_release.sh [VERSION]
#
# VERSION defaults to the MARKETING_VERSION in the project, or you can pass e.g. 1.0.0.
#
# Optional signing/notarization — set these to enable (otherwise skipped):
#   SIGN_IDENTITY        e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE       a notarytool keychain profile name created once via:
#                        xcrun notarytool store-credentials "<profile>" \
#                            --apple-id you@example.com --team-id TEAMID --password <app-specific-pw>
#
# Output:
#   dist/StandUp-<version>.zip
#   dist/StandUp-<version>.zip.sha256
#
set -euo pipefail

# --- Resolve paths -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/StandUp"
PROJECT="$PROJECT_DIR/StandUp.xcodeproj"
SCHEME="StandUp"
APP_NAME="StandUp"
DIST_DIR="$REPO_ROOT/dist"
BUILD_DIR="$REPO_ROOT/.release-build"

# --- Version -----------------------------------------------------------------
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ MARKETING_VERSION / {print $2; exit}')"
  VERSION="${VERSION:-0.0.0}"
fi
echo "==> Building StandUp version $VERSION"

# --- Clean build directories -------------------------------------------------
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# --- Build Release -----------------------------------------------------------
# Unsigned by default; if SIGN_IDENTITY is set, we sign the archive step later.
echo "==> Compiling (Release)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build \
  | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" | grep -v "appintents" || true

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: build did not produce $APP_PATH" >&2
  exit 1
fi
echo "==> Built: $APP_PATH"

# --- Stage the .app ----------------------------------------------------------
STAGE="$BUILD_DIR/stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
STAGED_APP="$STAGE/$APP_NAME.app"

# --- Optional: sign ----------------------------------------------------------
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "==> Signing with Developer ID: $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$STAGED_APP"
  codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
else
  echo "==> SIGN_IDENTITY not set — producing an UNSIGNED development build."
fi

# --- Package the .zip --------------------------------------------------------
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION.zip"
rm -f "$ZIP_PATH"
echo "==> Packaging $ZIP_PATH"
# ditto preserves resource forks / symlinks correctly for .app bundles.
ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$ZIP_PATH"

# --- Optional: notarize the zip ---------------------------------------------
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    echo "WARNING: NOTARY_PROFILE set but SIGN_IDENTITY is not — notarization requires signing. Skipping." >&2
  else
    echo "==> Submitting to Apple notary service (profile: $NOTARY_PROFILE)"
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling the ticket to the .app"
    xcrun stapler staple "$STAGED_APP"
    # Re-zip the stapled app so the ticket travels with the download.
    rm -f "$ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$ZIP_PATH"
    echo "==> Notarized & stapled."
  fi
else
  echo "==> NOTARY_PROFILE not set — skipping notarization."
fi

# --- SHA-256 -----------------------------------------------------------------
SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
echo "$SHA  $(basename "$ZIP_PATH")" > "$ZIP_PATH.sha256"

echo ""
echo "============================================================"
echo " StandUp $VERSION packaged"
echo "------------------------------------------------------------"
echo " File   : $ZIP_PATH"
echo " SHA-256: $SHA"
echo " Signed : $([[ -n "${SIGN_IDENTITY:-}" ]] && echo yes || echo no)"
echo "============================================================"
echo ""
echo "Cask update values:"
echo "  version \"$VERSION\""
echo "  sha256 \"$SHA\""
