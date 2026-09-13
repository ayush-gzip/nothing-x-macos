#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
sources=()
while IFS= read -r -d '' source; do sources+=("$source"); done < <(find "$project_dir/Nothing X MacOS/domain" "$project_dir/Nothing X MacOS/data" "$project_dir/Nothing X MacOS/framework" -name '*.swift' -print0)
swiftc -module-cache-path "${TMPDIR:-/tmp}/nothing-x-swift-check-cache" "${sources[@]}" "$project_dir/scripts/HeadphoneCheck.swift" -o "$check_dir/headphone-check"
"$check_dir/headphone-check"
