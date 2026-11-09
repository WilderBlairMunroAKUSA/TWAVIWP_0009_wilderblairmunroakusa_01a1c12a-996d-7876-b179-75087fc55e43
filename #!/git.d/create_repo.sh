#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/_lib.sh"

usage() { fail 'Usage: create_repo github|huggingface [--no-push]'; }
[[ $# -ge 1 ]] || usage
target=$1; shift
push=1
while (( $# )); do
  case $1 in
    --no-push) push=0 ;;
    *) usage ;;
  esac
  shift
done

require_command git
require_command jq
require_file _repo.json
[[ -e .git ]] || fail 'No local .git entry; run init_repo first'
[[ $(git rev-parse --show-toplevel) == "$PWD" ]] || fail 'Not at the root of this Git repository'
git rev-parse --verify HEAD >/dev/null 2>&1 || fail 'No local commit; run init_repo first'
branch=$(git symbolic-ref --quiet --short HEAD) || fail 'Detached HEAD; checkout a branch first'

# Never silently repoint an existing remote.
ensure_remote() {
  local remote=$1 url=$2 actual
  if actual=$(git remote get-url "$remote" 2>/dev/null); then
    [[ $actual == "$url" ]] || fail "Remote '$remote' already points to $actual (expected $url)"
  else
    git remote add "$remote" "$url"
  fi
}

case $target in
  github)
    require_command gh
    name=$(jq -er '.github.name | select(type == "string" and length > 0)' _repo.json)
    remote=$(jq -er '.github.remote // "origin" | select(type == "string" and length > 0)' _repo.json)
    # Initial local commit must be the first commit on the remote.
    jq -e '(.github.auto_init // false) == false and
           ((.github.gitignore_template // "") == "") and
           ((.github.license_template // "") == "")' _repo.json >/dev/null \
      || fail 'GitHub auto_init, gitignore_template and license_template must be disabled for initial push'
	
    # GitHub repositories must be created under the configured organization.
    owner=$(jq -er '.github.owner | select(type == "string" and length > 0)' _repo.json) \
      || fail 'Missing .github.owner organization in _repo.json'

    endpoint="/orgs/$owner/repos"
    url="https://github.com/$owner/$name.git"
    # Only send fields accepted by GitHub's create-repo API.
    payload=$(mktemp)
    trap 'rm -f -- "$payload"' EXIT
    jq -e '.github | {
      name, description, homepage, private, has_issues, has_projects,
      has_wiki, allow_squash_merge, allow_merge_commit, allow_rebase_merge,
      delete_branch_on_merge, auto_init
    } | with_entries(select(.value != null))' _repo.json > "$payload"
    if git remote get-url "$remote" >/dev/null 2>&1; then
      ensure_remote "$remote" "$url"
      printf 'GitHub remote already configured: %s\n' "$url"
    else
      gh api --method POST "$endpoint" --input "$payload" >/dev/null
      ensure_remote "$remote" "$url"
      printf 'Created GitHub repository: %s\n' "$url"
    fi
    ;;
  huggingface)
    require_command hf
    name=$(jq -er '.huggingface.name | select(type == "string" and length > 0)' _repo.json)
    namespace=$(jq -er '.huggingface.namespace | select(type == "string" and length > 0)' _repo.json) \
      || fail 'Set .huggingface.namespace in _repo.json'
    kind=$(jq -r '.huggingface.type // "model"' _repo.json)
    [[ $kind == model || $kind == dataset || $kind == space ]] || fail 'HF type must be model, dataset or space'
    remote=$(jq -er '.huggingface.remote // "huggingface" | select(type == "string" and length > 0)' _repo.json)
    private=$(jq -r '.huggingface.private // false | if type == "boolean" then . else error("private must be boolean") end' _repo.json)
    sdk=$(jq -r '.huggingface.sdk // empty' _repo.json)
    if [[ $kind == space && -z $sdk ]]; then fail 'Hugging Face Spaces require .huggingface.sdk'; fi
    if [[ $kind != space && -n $sdk ]]; then fail 'Hugging Face sdk only applies to Spaces'; fi
    case $kind in
      model) path="$namespace/$name" ;;
      dataset) path="datasets/$namespace/$name" ;;
      space) path="spaces/$namespace/$name" ;;
    esac
    url="https://huggingface.co/$path"
    if git remote get-url "$remote" >/dev/null 2>&1; then
      ensure_remote "$remote" "$url"
      printf 'Hugging Face remote already configured: %s\n' "$url"
    else
      args=(repos create "$namespace/$name" --repo-type "$kind")
      [[ $private == true ]] && args+=(--private)
      [[ $kind == space ]] && args+=(--sdk "$sdk")
      hf "${args[@]}"
      ensure_remote "$remote" "$url"
      printf 'Created Hugging Face repository: %s\n' "$url"
    fi
    ;;
  *) usage ;;
esac

# Hugging Face may initialize main with .gitattributes.
# Incorporate its existing history before the first push.
if [[ $target == huggingface ]] && (( push )); then
  if git ls-remote --exit-code --heads "$remote" main >/dev/null 2>&1; then
    git fetch "$remote" main
    git merge --allow-unrelated-histories --no-edit FETCH_HEAD
  fi
fi

if (( push )); then
  [[ $branch == main ]] || fail "Expected local branch 'main', got '$branch'"
  git push -u "$remote" HEAD:refs/heads/main
else
  printf 'Skipped push (--no-push).\n'
fi
