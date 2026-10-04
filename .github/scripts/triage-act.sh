#!/usr/bin/env bash
# Last step of issue-triage.yml: check the model's verdict, then label and
# comment. The model cannot post; this script decides what is posted.
#
# Needs: GH_TOKEN, NUMBER, OUTCOME, VERDICT, RUN_URL.
set -euo pipefail
: "${GH_TOKEN:?}" "${NUMBER:?}" "${RUN_URL:?}"

LABEL='**{{PROJECT}} Triage Agent here.**'
conf() { sed -n "s/^$1=//p" agents/rails.conf | tail -n 1; }
owners=$(conf owners)
maintainer=$(conf maintainer)
body=$(mktemp)

post() { gh issue comment "$NUMBER" --body-file "$body"; }

# Model text goes on a public issue: cap it, break @mentions, drop images
# (a remote image is a request to someone else's server), and remove any
# credential this job holds.
clean() {
  local s=${1:0:800}
  s=${s//@/@​}  # a zero-width space after each @, so no one is pinged
  s=${s//'!['/'['}
  local v
  for v in "${AWS_ACCESS_KEY_ID:-}" "${AWS_SECRET_ACCESS_KEY:-}" "${AWS_SESSION_TOKEN:-}" "$GH_TOKEN"; do
    [[ -n "$v" ]] && s=${s//"$v"/[redacted]}
  done
  printf '%s' "$s"
}

if [[ "${OUTCOME:-}" != success ]] || ! jq -e '
    type == "object"
    and (.kind | IN("accessibility","bug","enhancement","question","other"))
    and (.ready | type == "boolean")
    and (.missing | type == "string")
    and (.summary | type == "string")
    and (.duplicate_of == null or (.duplicate_of | type == "number"))' <<<"${VERDICT:-}" >/dev/null 2>&1; then
  printf '%s\n\nTriage did not finish, so a person should look at this issue. [Run log](%s)\n' "$LABEL" "$RUN_URL" >"$body"
  post
  gh issue edit "$NUMBER" --add-label needs-human
  exit 0
fi

kind=$(jq -r .kind <<<"$VERDICT")
ready=$(jq -r .ready <<<"$VERDICT")
summary=$(clean "$(jq -r .summary <<<"$VERDICT")")
missing=$(clean "$(jq -r .missing <<<"$VERDICT")")
dup=$(jq -r '.duplicate_of // empty' <<<"$VERDICT")
# Only an open issue counts as a duplicate.
[[ -n "$dup" ]] && ! grep -qxF "$dup" /tmp/triage/open.txt && dup=""

[[ "$kind" != other ]] && gh issue edit "$NUMBER" --add-label "$kind"

{
  printf '%s\n\n%s\n' "$LABEL" "$summary"
  [[ -n "$dup" ]] && printf '\nThis may be the same as #%s. An owner will decide.\n' "$dup"
  if [[ "$ready" == true ]]; then
    printf '\n%s: this looks ready. To start work, assign it to @%s.\n' "$(printf '@%s ' $owners | sed 's/ $//')" "$maintainer"
  else
    printf '\nTo work on this, we need:\n\n%s\n\nReply here and triage will look again.\n' "$missing"
  fi
} >"$body"
post

if [[ "$ready" == true ]]; then
  gh issue edit "$NUMBER" --add-label triaged --remove-label needs-info
else
  gh issue edit "$NUMBER" --add-label needs-info --remove-label triaged
fi
