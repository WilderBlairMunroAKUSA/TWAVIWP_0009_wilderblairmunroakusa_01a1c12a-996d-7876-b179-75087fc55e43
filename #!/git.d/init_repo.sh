#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/_lib.sh"

prepare_only=0
case ${1:-} in
  '') ;;
  --prepare) prepare_only=1; shift ;;
  *) fail 'Usage: init_repo [--prepare]' ;;
esac
(( $# == 0 )) || fail 'Usage: init_repo [--prepare]'

require_command jq
require_command git

name=${PWD##*/}
re='^([^_]+)_([0-9]{4})_([^_]+)_([[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12})$'

[[ $name =~ $re ]] || fail 'Expected directory name: CHANNEL_SHOW_OPERATORSLUG_UUID'

channel=${BASH_REMATCH[1]}
show=${BASH_REMATCH[2]}
operator_slug=${BASH_REMATCH[3]}
uuid=${BASH_REMATCH[4]}

root="_root.$uuid.json"
require_file _repo.json

# Only inspect Git history if THIS directory already has a .git entry.
# Nested repositories are allowed.
if [[ -e .git ]] && git rev-parse --verify HEAD >/dev/null 2>&1; then
  fail 'This directory already has a Git commit. Refusing to replace gitinitcommit.'
fi

if [[ ! -f $root ]]; then
  shopt -s nullglob
  roots=( _root.*.json )
  shopt -u nullglob
  (( ${#roots[@]} == 1 )) || fail "Expected $root, or exactly one _root.*.json template"
  mv -- "${roots[0]}" "$root"
  printf 'renamed %s -> %s\n' "${roots[0]}" "$root"
fi

require_file README.md

# macOS BSD sed: replace only the first line.
sed -i '' "1s|.*|#### Daychorder entry $name|" README.md

json_edit "$root" \
  --arg channel "$channel" \
  --arg show "$show" \
  --arg operator_slug "$operator_slug" \
  --arg uuid "$uuid" \
  --arg date "$(date +%F)" \
  '
    .channel = $channel |
    .show = $show |
    .operator_slug = $operator_slug |
    .date = $date |
    .uuid = $uuid |
    .gitinitcommit = "" |
    .gitsealcommit = ""
  '

# Derive remote ownership from the prepared root metadata.
operator_alias=$(jq -er '.operator_alias | select(type == "string" and length > 0)' "$root")

json_edit _repo.json \
  --arg name "$name" \
  --arg owner "$operator_alias" \
  '
    .github.name = $name |
    .github.owner = $owner |
    .github.description = ("Daycorder entry " + $name) |
    .huggingface.name = $name |
    .huggingface.namespace = $owner
  '

if (( prepare_only )); then
  printf 'prepared _repo.json and %s (no Git changes)\n' "$root"
  exit 0
fi

[[ -e .git ]] || git init -q -b main
git add -A
git diff --cached --quiet && fail 'No staged files for an initial commit'
git commit -m 'Initial commit'
sha=$(git rev-parse HEAD)
json_edit "$root" --arg sha "$sha" '.gitinitcommit = $sha'
printf '\ngitinitcommit = %s\n' "$sha"
printf 'Note: %s now has an uncommitted metadata update (for the later seal).\n' "$root"
