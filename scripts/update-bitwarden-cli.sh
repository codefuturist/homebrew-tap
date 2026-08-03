#!/usr/bin/env bash
# Resolve the newest Bitwarden CLI release (tags `cli-v*` in bitwarden/clients,
# whose releases interleave desktop/web/browser/cli — never use /releases/latest),
# read the four official `bw-*.zip` asset sha256 digests from the GitHub REST
# API asset metadata, and rewrite Formula/bitwarden-cli.rb in place.
#
# Exits 0 both when up to date (no diff) and when updated (diff present);
# the caller detects change via `git diff`. `--check` resolves and prints
# without writing. Hard-fails if any of the four digests is missing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA="$ROOT/Formula/bitwarden-cli.rb"
MODE="${1:-}"

current="$(grep -m1 -oE 'cli-v[0-9]+(\.[0-9]+)+' "$FORMULA" | sed 's/^cli-v//' || true)"
[ -n "$current" ] || { echo "ERROR: cannot read current version from $FORMULA" >&2; exit 1; }

latest_tag="$(gh api 'repos/bitwarden/clients/releases?per_page=100' \
  --jq '[.[] | select(.draft == false and .prerelease == false)
             | .tag_name | select(startswith("cli-v"))][0]')"
[ -n "$latest_tag" ] && [ "$latest_tag" != "null" ] || { echo "ERROR: no cli-v* release in first 100 releases" >&2; exit 1; }
latest="${latest_tag#cli-v}"
echo "current=$current latest=$latest"

if [ "$latest" = "$current" ]; then
  echo "bitwarden-cli already at $current — nothing to do"; exit 0
fi
# Downgrade guard (release-retraction safety); sort -V works on macOS + GNU.
if [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)" != "$latest" ]; then
  echo "latest ($latest) is not newer than current ($current) — skipping"; exit 0
fi

release_json="$(gh api "repos/bitwarden/clients/releases/tags/${latest_tag}")"
digest() { # $1 = asset name -> bare 64-hex sha256, or hard-fail
  local d
  d="$(jq -r --arg n "$1" '.assets[] | select(.name == $n) | .digest // empty' <<<"$release_json")"
  if ! printf '%s' "$d" | grep -qE '^sha256:[0-9a-f]{64}$'; then
    echo "ERROR: missing/invalid digest for asset $1 (got: '${d}')" >&2; exit 1
  fi
  printf '%s' "${d#sha256:}"
}
sha_mac_arm="$(digest "bw-macos-arm64-${latest}.zip")"
sha_mac_x64="$(digest "bw-macos-${latest}.zip")"
sha_lin_arm="$(digest "bw-linux-arm64-${latest}.zip")"
sha_lin_x64="$(digest "bw-linux-${latest}.zip")"

if [ "$MODE" = "--check" ]; then
  printf 'would update %s -> %s\n  macos-arm64 %s\n  macos-x64   %s\n  linux-arm64 %s\n  linux-x64   %s\n' \
    "$current" "$latest" "$sha_mac_arm" "$sha_mac_x64" "$sha_lin_arm" "$sha_lin_x64"
  exit 0
fi

# Single-pass rewrite: each url line (version appears twice) + its following
# sha256 line. `bw-macos-[0-9]` only matches x64 (arm64 continues with `a`).
tmp="$(mktemp)"
awk -v v="$latest" -v a="$sha_mac_arm" -v b="$sha_mac_x64" -v c="$sha_lin_arm" -v d="$sha_lin_x64" '
  /url ".*\/bw-(macos|linux)/ {
    if ($0 ~ /bw-macos-arm64-/)      pending = a
    else if ($0 ~ /bw-macos-[0-9]/)  pending = b
    else if ($0 ~ /bw-linux-arm64-/) pending = c
    else if ($0 ~ /bw-linux-[0-9]/)  pending = d
    gsub(/[0-9]+(\.[0-9]+)+/, v)
    n_url++
  }
  pending != "" && /sha256 "/ {
    sub(/"[0-9a-f]+"/, "\"" pending "\"")
    pending = ""; n_sha++
  }
  { print }
  END { if (n_url != 4 || n_sha != 4) exit 3 }
' "$FORMULA" > "$tmp" || { echo "ERROR: expected exactly 4 url + 4 sha256 rewrites" >&2; rm -f "$tmp"; exit 1; }

[ "$(grep -c "cli-v${latest}/bw-" "$tmp")" -eq 4 ] || { echo "ERROR: url verification failed" >&2; exit 1; }
for s in "$sha_mac_arm" "$sha_mac_x64" "$sha_lin_arm" "$sha_lin_x64"; do
  [ "$(grep -c "\"$s\"" "$tmp")" -eq 1 ] || { echo "ERROR: sha256 $s not present exactly once" >&2; exit 1; }
done
if grep -qF "$current" "$tmp"; then
  echo "ERROR: old version $current still present" >&2; exit 1
fi
ruby -c "$tmp" >/dev/null || { echo "ERROR: rewritten formula is not valid Ruby" >&2; exit 1; }

mv "$tmp" "$FORMULA"
echo "updated Formula/bitwarden-cli.rb: $current -> $latest"
