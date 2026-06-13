#!/usr/bin/env bash
# Detect the latest Eddie AI version and update Casks/eddie-ai.rb in place.
#
# Cheap-gated: HEAD the S3 dmg for its ETag (a single-part ETag == the file's
# md5, so it changes exactly when a new build is published). Only when the ETag
# differs from the `# source-etag:` recorded in the cask do we fetch the dmg,
# mount it read-only, and read the real CFBundleShortVersionString.
#
# Must run on macOS: the dmg is UDIF/lzfse (ULFO), which only `hdiutil` can read.
# The committing/pushing is left to the calling workflow.
set -euo pipefail

URL="https://eddie-desktop-app.s3.us-east-2.amazonaws.com/distributions/darwin/arm64/Eddie+AI.dmg"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASK="$ROOT/Casks/eddie-ai.rb"
FORCE="${1:-}"

etag="$(curl -fsSI "$URL" | tr -d '\r' | awk -F': ' 'tolower($1)=="etag"{gsub(/"/,"",$2); print $2}')"
[ -n "$etag" ] || { echo "ERROR: no ETag from $URL" >&2; exit 1; }
cur="$(awk '/^# source-etag:/{print $3; exit}' "$CASK")"

if [ "$etag" = "$cur" ] && [ "$FORCE" != "--force" ]; then
  echo "No change (ETag $etag) — cask already current"
  exit 0
fi
echo "Artifact changed (${cur:-none} -> $etag) — resolving real version"

tmp="$(mktemp -d)"; mnt="$tmp/mnt"; dmg=""
trap 'hdiutil detach "$mnt" >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
mkdir -p "$mnt"

# Reuse a local copy whose md5 already matches (no-op on CI runners; saves a
# 200 MB download when run on a Mac that already has the dmg cached).
shopt -s nullglob
for cand in "$HOME"/Library/Caches/Homebrew/downloads/*Eddie*AI*.dmg; do
  if [ "$(md5 -q "$cand")" = "$etag" ]; then dmg="$cand"; echo "reusing cached dmg: $cand"; break; fi
done
shopt -u nullglob
if [ -z "$dmg" ]; then dmg="$tmp/e.dmg"; echo "downloading dmg…"; curl -fsSL "$URL" -o "$dmg"; fi

hdiutil attach -nobrowse -readonly -noverify -noautoopen -mountpoint "$mnt" "$dmg" >/dev/null
ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$mnt/Eddie AI.app/Contents/Info.plist")"
hdiutil detach "$mnt" >/dev/null 2>&1 || true
[ -n "$ver" ] || { echo "ERROR: could not read CFBundleShortVersionString" >&2; exit 1; }
echo "Latest version: $ver"

/usr/bin/sed -i '' -E "s/^(  version )\"[^\"]*\"/\1\"$ver\"/" "$CASK"
/usr/bin/sed -i '' -E "s/^(# source-etag: ).*/\1$etag/" "$CASK"
echo "Updated $CASK to version \"$ver\" (etag $etag)"
