#!/usr/bin/env bash
# Put the agent setup from UIC OSF's AI-Powered Software Factory Building Blocks into a repo and fill in its placeholders.
#
#   scripts/adopt.sh <target> --project NAME --repo OWNER/NAME --human LOGIN --maintainer LOGIN [--description TEXT]
#
# --human is the first owner. --maintainer is the maintainer agent's own GitHub account.
#
# Target "." in a repo made from this template: fills placeholders in place and
# replaces this README with the project's.
# Any other target (an existing project): copies the kit in. Files the target
# already has are never overwritten; they are listed for you to merge by hand.
set -euo pipefail

usage() { sed -n 2,12p "$0" | sed 's/^# \{0,1\}//'; exit 2; }

[[ $# -ge 1 ]] || usage
target=$1; shift
project="" repo="" human="" maintainer="" description=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) project=$2; shift 2 ;;
    --repo) repo=$2; shift 2 ;;
    --human) human=${2#@}; shift 2 ;;
    --maintainer) maintainer=${2#@}; shift 2 ;;
    --description) description=$2; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$project" && -n "$human" && -n "$maintainer" && "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || usage
[[ -n "$description" ]] || description="<!-- One plain sentence: what $project does and for whom. -->"
slug=$(printf '%s' "${repo#*/}" | tr '[:upper:]' '[:lower:]')

src=$(cd "$(dirname "$0")/.." && pwd)
dst=$(cd "$target" && pwd)

KIT=(
  CLAUDE.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md LICENSE
  agents
  .claude/settings.json .claude/scripts .claude/commands
  .github/workflows/code-review.yml .github/workflows/ci.yml
  .github/workflows/rails.yml .github/workflows/issue-triage.yml
  .github/scripts/checks.sh .github/scripts/rails.sh .github/scripts/triage-act.sh
  .github/ISSUE_TEMPLATE .github/CODEOWNERS .github/pull_request_template.md .github/dependabot.yml
  docs/getting-started.md templates/maintainer-state.md
)

files=()     # files to fill placeholders in
skipped=()   # already in the target

if [[ "$src" == "$dst" ]]; then
  while IFS= read -r f; do files+=("$f"); done < <(cd "$src" && find "${KIT[@]}" -type f)
  cp "$src/templates/README.md" "$src/README.md"
  rm "$src/templates/README.md" "$src/AGENT-SETUP.md"
  files+=(README.md)
else
  while IFS= read -r f; do
    if [[ -e "$dst/$f" ]]; then
      skipped+=("$f")
    else
      mkdir -p "$dst/$(dirname "$f")"
      cp -p "$src/$f" "$dst/$f"
      files+=("$f")
    fi
  done < <(cd "$src" && find "${KIT[@]}" -type f)
  if [[ ! -e "$dst/README.md" ]]; then
    cp "$src/templates/README.md" "$dst/README.md"
    files+=(README.md)
  fi
  # .gitignore: append the lines the target lacks.
  touch "$dst/.gitignore"
  while IFS= read -r line; do
    grep -qxF -- "$line" "$dst/.gitignore" || printf '%s\n' "$line" >> "$dst/.gitignore"
  done < <(grep -v '^#' "$src/.gitignore" | grep -v '^$')
fi

# Values go through the environment, so no character in them is special to perl.
for f in "${files[@]}"; do
  P="$project" R="$repo" H="$human" M="$maintainer" D="$description" S="$slug" perl -pi -e '
    s/\{\{PROJECT\}\}/$ENV{P}/g; s/\{\{REPO\}\}/$ENV{R}/g; s/\{\{HUMAN\}\}/$ENV{H}/g;
    s/\{\{MAINTAINER\}\}/$ENV{M}/g;
    s/\{\{DESCRIPTION\}\}/$ENV{D}/g; s/\{\{SLUG\}\}/$ENV{S}/g' "$dst/$f"
done

echo "Adopted into $dst (${#files[@]} files)."
if (( ${#skipped[@]} )); then
  echo
  echo "Already there, not changed. Merge these by hand from $src:"
  printf '  %s\n' "${skipped[@]}"
fi
echo
echo "Next: docs/getting-started.md, from \"Then make it yours\"."
