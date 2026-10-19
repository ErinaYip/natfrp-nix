#!/usr/bin/env bash
# Refresh `version` and `hashes` in flake.nix from the upstream Natfrp mirror.
#
# Usage:
#   ./update-hashes.sh          # refresh hashes for the currently pinned version
#   ./update-hashes.sh 3.1.9    # bump to a new version and refresh hashes
#
# Requires: curl, nix (for `nix hash convert`), coreutils.
set -euo pipefail

cd "$(dirname "$0")"

base_url="https://nya.globalslb.net/natfrp/client/launcher-unix"
systems=(x86_64-linux aarch64-linux i686-linux armv7l-linux riscv64-linux)
declare -A arch_for=(
  [x86_64-linux]=amd64
  [aarch64-linux]=arm64
  [i686-linux]=386
  [armv7l-linux]=armv7
  [riscv64-linux]=riscv64
)

current_version="$(sed -n 's/^ *version = "\(.*\)";$/\1/p' flake.nix | head -n1)"
if [ -z "$current_version" ]; then
  echo "error: cannot determine the current version from flake.nix" >&2
  exit 1
fi

version="${1:-$current_version}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

: > "$tmp_dir/hashes"

for system in "${systems[@]}"; do
  arch="${arch_for[$system]}"
  url="$base_url/$version/natfrp-service_linux_${arch}.tar.zst"
  echo "fetching $url" >&2
  curl -fsSL -o "$tmp_dir/$arch.tar.zst" "$url"
  hash="$(nix hash convert --hash-algo sha256 --to sri \
    "$(sha256sum "$tmp_dir/$arch.tar.zst" | cut -d' ' -f1)")"
  printf '        %s = "%s";\n' "$system" "$hash" >> "$tmp_dir/hashes"
done

awk -v version="$version" -v hashes_file="$tmp_dir/hashes" '
  BEGIN {
    while ((getline line < hashes_file) > 0) {
      hashes = hashes line "\n"
    }
    close(hashes_file)
  }
  !version_done && $0 ~ /^ *version = ".*";$/ {
    indent = substr($0, 1, index($0, "version") - 1)
    print indent "version = \"" version "\";"
    version_done = 1
    next
  }
  in_hashes {
    if ($0 ~ /^ *};$/) {
      printf "%s", hashes
      in_hashes = 0
      print
    }
    next
  }
  $0 ~ /^ *hashes = \{$/ {
    print
    in_hashes = 1
    next
  }
  { print }
' flake.nix > "$tmp_dir/flake.nix"

mv "$tmp_dir/flake.nix" flake.nix

echo "flake.nix now pins version $version:" >&2
cat "$tmp_dir/hashes" >&2
