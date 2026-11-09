#!/usr/bin/env bash

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
require_file() { [[ -f $1 ]] || fail "Missing file: $1"; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "Missing dependency: $1"; }

# Atomic rewrite, leaving the original untouched if jq fails.
json_edit() {
  local file=$1 tmp
  shift
  tmp="${file}.tmp.$$"
  jq "$@" "$file" > "$tmp" || { rm -f -- "$tmp"; fail "Could not update $file"; }
  mv -- "$tmp" "$file"
}
