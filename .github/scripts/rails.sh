#!/usr/bin/env bash
# The `rails` check (agents/rails.md): PR size and the off switch.
# Runs from the base branch and reads agents/rails.conf there. It only calls the
# GitHub API; it never runs the PR's code.
#
# Needs: GH_TOKEN, REPO (owner/name), PR (number). Optional: AGENTS_PAUSED.
set -euo pipefail
: "${GH_TOKEN:?}" "${REPO:?}" "${PR:?}"

conf() { sed -n "s/^$1=//p" agents/rails.conf | tail -n 1; }
owners=" $(conf owners) "
maintainer=$(conf maintainer)
max_lines=$(conf max_changed_lines)
max_files=$(conf max_changed_files)

pr=$(gh api "repos/$REPO/pulls/$PR")
author=$(jq -r .user.login <<<"$pr")
lines=$(jq '.additions + .deletions' <<<"$pr")
files=$(jq .changed_files <<<"$pr")
failed=0

if [[ "${AGENTS_PAUSED:-}" == true && "$author" == "$maintainer" ]]; then
  echo "fail: agents are paused (AGENTS_PAUSED=true)."
  failed=1
fi

echo "size: $lines lines, $files files (limits $max_lines, $max_files)"
if (( lines > max_lines || files > max_files )); then
  if jq -e 'any(.labels[]; .name == "large-ok")' <<<"$pr" >/dev/null; then
    by=$(gh api --paginate "repos/$REPO/issues/$PR/events" \
      --jq '.[] | select(.event == "labeled" and .label.name == "large-ok") | .actor.login' | tail -n 1)
    if [[ -n "$by" && "$owners" == *" $by "* ]]; then
      echo "pass: over the limit, and owner @$by added large-ok."
    else
      echo "fail: large-ok was added by @$by, who is not an owner (owners:$owners)."
      failed=1
    fi
  else
    echo "fail: over the limit. Split the PR, or an owner adds the large-ok label."
    failed=1
  fi
fi

exit "$failed"
