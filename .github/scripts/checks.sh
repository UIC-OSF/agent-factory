#!/usr/bin/env bash
# The project's checks, in one place. CI runs them as a gate; the review
# workflow runs them as a report for the reviewer. Add project checks to the
# CHECKS list below; each line is "name|command".
#
# Usage:
#   .github/scripts/checks.sh                 run all, exit 1 if any fail
#   .github/scripts/checks.sh --report FILE   append results to FILE as markdown,
#                                             write the summary to
#                                             /tmp/check-summary.md, always exit 0
set -uo pipefail

CHECKS=(
  "workflow lint (actionlint)|run_actionlint"
  "workflow scripts (shellcheck)|run_shellcheck"
  # "typecheck|npm run typecheck"
  # "tests|npm test"
)

# Pinned and checksum-verified: the review job holds id-token: write.
# Bump version and checksum together.
ACTIONLINT_VERSION=1.7.12
ACTIONLINT_SHA256=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
TAIL_LINES=40

# Exit 0 pass, 1 fail, 2 skip.
run_actionlint() {
  local bin
  bin=$(command -v actionlint || true)
  if [[ -z "$bin" ]]; then
    [[ "$(uname -s)-$(uname -m)" == Linux-x86_64 ]] || { echo "actionlint not installed"; return 2; }
    bin=/tmp/actionlint
    if [[ ! -x "$bin" ]]; then
      curl -fsSL -o /tmp/actionlint.tgz \
        "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz" \
        && echo "${ACTIONLINT_SHA256}  /tmp/actionlint.tgz" | sha256sum -c - >/dev/null 2>&1 \
        && tar -xzf /tmp/actionlint.tgz -C /tmp actionlint \
        || { echo "could not install actionlint v${ACTIONLINT_VERSION}"; return 2; }
    fi
  fi
  "$bin" -shellcheck= -pyflakes= .github/workflows/*.yml
}

run_shellcheck() {
  command -v shellcheck >/dev/null || { echo "shellcheck not installed"; return 2; }
  shopt -s nullglob
  local files=(.github/scripts/*.sh .claude/scripts/*.sh scripts/*.sh)
  (( ${#files[@]} )) || { echo "no scripts"; return 2; }
  shellcheck -s bash -S warning "${files[@]}"
}

report=""
if [[ "${1:-}" == "--report" ]]; then
  report=${2:?--report needs a file}
fi

cd "$(git rev-parse --show-toplevel)" || exit 1
summary="## Check summary"$'\n'
failed=0

for entry in "${CHECKS[@]}"; do
  name=${entry%%|*}
  cmd=${entry#*|}
  log=$(mktemp)
  # A check's output is captured to a file, not piped: `| tail` under pipefail
  # would kill a long-running check with SIGPIPE.
  ( eval "$cmd" ) >"$log" 2>&1
  case $? in
    0) result=pass ;;
    2) result=skip ;;
    *) result=fail; failed=1 ;;
  esac
  summary+="- ${name}: ${result}"$'\n'
  if [[ -n "$report" ]]; then
    { echo; echo "## ${name}"; echo '```'; tail -n "$TAIL_LINES" "$log"; echo '```'; echo; echo "Result: **${result}**"; } >>"$report"
  else
    echo "::group::${name}: ${result}"; cat "$log"; echo "::endgroup::"
  fi
  rm -f "$log"
done

if [[ -n "$report" ]]; then
  { echo; printf '%s' "$summary"; } >>"$report"
  printf '%s' "$summary" >/tmp/check-summary.md
  exit 0
fi
printf '%s' "$summary"
exit "$failed"
