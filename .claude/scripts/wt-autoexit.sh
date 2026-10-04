#!/usr/bin/env bash
# Stop hook. When this session is sitting in a worktree whose PR has merged and
# the checkout is clean, hand Claude one instruction: leave and delete it.
#
# A shell script cannot remove the worktree a live session is standing in, so
# this does not try. It blocks the turn once with a reason, and Claude does it
# properly via ExitWorktree.
#
# Deliberately quiet and cheap:
#   - nothing happens unless cwd is inside .claude/worktrees/
#   - no `gh` call until the branch actually exists on the remote
#   - no `gh` call more than once a minute (throttle file)
#   - fires at most once per session+branch (marker file)
#   - never fires when there is uncommitted or unpushed work
set -uo pipefail

THROTTLE_SECS=60

payload=$(cat 2>/dev/null || true)
[[ -n "$payload" ]] || exit 0

hook_active=0 session_id=nosession cwd=""
eval "$(printf '%s' "$payload" | python3 -c '
import json, shlex, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print("hook_active=%d" % (1 if d.get("stop_hook_active") else 0))
print("session_id=%s" % shlex.quote(str(d.get("session_id") or "nosession")))
print("cwd=%s" % shlex.quote(str(d.get("cwd") or "")))
' 2>/dev/null)" 2>/dev/null || exit 0

# Already inside a continuation this hook caused: never block twice.
(( ${hook_active:-0} )) && exit 0
[[ -n "${cwd:-}" ]] || cwd=$PWD
[[ -d "$cwd" ]] || exit 0

common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
root=${common%/.git}
self=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ "$self" == "$root/.claude/worktrees/"* ]] || exit 0        # not in a worktree

br=$(git -C "$self" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[[ -n "$br" && "$br" != "HEAD" && "$br" != "main" ]] || exit 0

# No remote branch means no PR yet — cheapest possible exit, no network.
git -C "$root" rev-parse --verify --quiet "refs/remotes/origin/$br" >/dev/null || exit 0

# Unsaved or unpushed work: stay out of the way entirely.
[[ -z "$(git -C "$self" status --porcelain 2>/dev/null)" ]] || exit 0
unpushed=$(git -C "$root" rev-list --count "origin/$br..$br" 2>/dev/null || echo 1)
(( unpushed == 0 )) || exit 0

state="$root/.claude/.wt-state"
mkdir -p "$state" 2>/dev/null || exit 0
safe=${br//\//_}
marker="$state/fired-$session_id-$safe"
[[ -e "$marker" ]] && exit 0

now=$(date +%s)
throttle="$state/checked-$safe"
if [[ -f "$throttle" ]]; then
  last=$(cat "$throttle" 2>/dev/null || echo 0)
  [[ "$last" =~ ^[0-9]+$ ]] || last=0
  (( now - last < THROTTLE_SECS )) && exit 0
fi
printf '%s' "$now" > "$throttle" 2>/dev/null

command -v gh >/dev/null || exit 0
pr=$(gh pr list --head "$br" --state merged --limit 1 --json number -q '.[0].number' 2>/dev/null) || exit 0
[[ -n "$pr" ]] || exit 0

: > "$marker" 2>/dev/null
python3 - "$br" "$pr" <<'PY' 2>/dev/null || true
import json, sys
br, pr = sys.argv[1], sys.argv[2]
reason = (
    f"PR #{pr} for this worktree's branch ({br}) has merged, and the worktree is "
    "clean with nothing unpushed. Call ExitWorktree with action \"remove\" to return "
    "to the main repository and delete this worktree and its branch. Then tell the "
    "user in one short line that it was cleaned up. Do not start any new work and do "
    "not ask for confirmation."
)
print(json.dumps({"decision": "block", "reason": reason}))
PY
exit 0
