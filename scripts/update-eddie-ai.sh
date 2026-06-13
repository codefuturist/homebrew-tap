#!/usr/bin/env bash
# Detect the latest Eddie AI version + per-arch sha256 and update Casks/eddie-ai.rb.
#
# Cheap-gated on the arm64 dmg's S3 ETag (single-part ETag == md5). Only when it
# changes do we fetch BOTH arch dmgs, read the real CFBundleShortVersionString
# from the arm64 image (mounted read-only), compute both sha256 values, and
# rewrite the cask's `version`, the per-arch `sha256` lines, and the
# `# source-etag:` comment.
#
# macOS only: the dmg is UDIF/lzfse (ULFO); only hdiutil can mount it.
set -euo pipefail

BASE="https://eddie-desktop-app.s3.us-east-2.amazonaws.com/distributions/darwin"
ARM_URL="$BASE/arm64/Eddie+AI.dmg"
X64_URL="$BASE/x64/Eddie+AI.dmg"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASK="$ROOT/Casks/eddie-ai.rb"
FORCE="${1:-}"

head_etag() { curl -fsSI "$1" | tr -d '\r' | awk -F': ' 'tolower($1)=="etag"{gsub(/"/,"",$2); print $2}'; }

etag="$(head_etag "$ARM_URL")"
[ -n "$etag" ] || { echo "ERROR: no ETag from $ARM_URL" >&2; exit 1; }
cur="$(awk '/^# source-etag:/{print $3; exit}' "$CASK")"

if [ "$etag" = "$cur" ] && [ "$FORCE" != "--force" ]; then
  echo "No change (ETag $etag) — cask already current"
  exit 0
fi
echo "Artifact changed (${cur:-none} -> $etag) — resolving version + checksums"

tmp="$(mktemp -d)"; mnt="$tmp/mnt"; mkdir -p "$mnt"
trap 'hdiutil detach "$mnt" >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT

# Fetch a dmg, reusing a local copy whose md5 already matches (no-op on CI runners;
# saves a re-download on a Mac that already has it in Homebrew's cache).
fetch() { # $1=url $2=etag -> path on stdout
  local url="$1" et="$2" f
  shopt -s nullglob
  for f in "$HOME"/Library/Caches/Homebrew/downloads/*Eddie*AI*.dmg; do
    if [ "$(md5 -q "$f")" = "$et" ]; then shopt -u nullglob; echo "$f"; return; fi
  done
  shopt -u nullglob
  f="$tmp/$(printf '%s' "$url" | md5).dmg"
  curl -fsSL "$url" -o "$f"
  echo "$f"
}

arm_dmg="$(fetch "$ARM_URL" "$etag")"
x64_dmg="$(fetch "$X64_URL" "$(head_etag "$X64_URL")")"

hdiutil attach -nobrowse -readonly -noverify -noautoopen -mountpoint "$mnt" "$arm_dmg" >/dev/null
ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$mnt/Eddie AI.app/Contents/Info.plist")"
hdiutil detach "$mnt" >/dev/null 2>&1 || true
[ -n "$ver" ] || { echo "ERROR: could not read CFBundleShortVersionString" >&2; exit 1; }

arm_sha="$(shasum -a 256 "$arm_dmg" | awk '{print $1}')"
x64_sha="$(shasum -a 256 "$x64_dmg" | awk '{print $1}')"
echo "version=$ver  arm64=$arm_sha  x64=$x64_sha"

/usr/bin/sed -i '' -E "s/^(  version )\"[^\"]*\"/\1\"$ver\"/" "$CASK"
# Per-arch sha256 lives inside the on_arm / on_intel blocks; scope each edit to its block.
/usr/bin/sed -i '' -E "/on_arm do/,/^  end/  s/(sha256 \")[^\"]*\"/\1$arm_sha\"/" "$CASK"
/usr/bin/sed -i '' -E "/on_intel do/,/^  end/ s/(sha256 \")[^\"]*\"/\1$x64_sha\"/" "$CASK"
/usr/bin/sed -i '' -E "s/^(# source-etag: ).*/\1$etag/" "$CASK"
echo "Updated $CASK to version \"$ver\" with per-arch sha256"
