#!/usr/bin/env bash
# Remove Claude Code worktrees whose PR has landed, plus the branches and
# leftover directories that come with them.
#
# A worktree under .claude/worktrees/ is removed only when ALL of these hold:
#   - a merged PR exists for its branch (asked of GitHub, because squash merges
#     are invisible to `git branch --merged`)
#   - `git status --porcelain` in it is clean
#   - it has no commits missing from origin/<branch>
#   - it is not the worktree this session is sitting in
# Anything else is reported and left alone. --force drops the clean/unpushed
# checks for merged worktrees only; a worktree without a merged PR is never
# touched, with or without --force.
#
# Usage: .claude/scripts/wt-cleanup.sh [--force] [--quiet] [--hook]

set -uo pipefail
shopt -s nullglob dotglob

force=0 quiet=0 hook=0
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    --quiet) quiet=1 ;;
    --hook)  hook=1 quiet=1 ;;
    *) printf 'unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

say() { (( quiet )) || printf '%s\n' "$*"; }

# --git-common-dir resolves to the main repo even when we are inside a worktree.
common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
root=${common_dir%/.git}
wt_root="$root/.claude/worktrees"
[[ -d "$wt_root" ]] || exit 0

self=$(git rev-parse --show-toplevel 2>/dev/null || true)

# ---- read the registered worktrees -----------------------------------------
paths=() branches=()
read_worktrees() {
  paths=() branches=()
  local line p="" b=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) p=${line#worktree }; b="" ;;
      "branch refs/heads/"*) b=${line#branch refs/heads/} ;;
      "") [[ -n $p ]] && { paths+=("$p"); branches+=("$b"); }; p="" b="" ;;
    esac
  done < <(git -C "$root" worktree list --porcelain 2>/dev/null)
  [[ -n $p ]] && { paths+=("$p"); branches+=("$b"); }
  return 0
}
read_worktrees

# Where a path sits relative to the registered worktrees under .claude/worktrees:
#   live      it IS a worktree, or lives inside one  -> never touch, never enter
#   ancestor  a worktree sits below it               -> a real parent (names may
#                                                       contain "/"), so recurse
#   orphan    neither                                -> leftover, safe to delete
classify() {
  local p
  for p in ${wt_paths[@]+"${wt_paths[@]}"}; do
    [[ "$1" == "$p" || "$1" == "$p"/* ]] && { printf live; return; }
  done
  for p in ${wt_paths[@]+"${wt_paths[@]}"}; do
    [[ "$p" == "$1"/* ]] && { printf ancestor; return; }
  done
  printf orphan
}

# Registered worktrees under .claude/worktrees only. The main repo root is also
# in `paths` and is an ancestor of everything here, so it must stay out of this.
wt_paths=()
collect_wt_paths() {
  wt_paths=()
  local p
  for p in "${paths[@]}"; do
    [[ "$p" == "$wt_root"/* ]] && wt_paths+=("$p")
  done
  return 0
}
collect_wt_paths

# Fills `orphans` with the top-most leftover entries; does not descend into them.
orphans=()
collect_orphans() {
  orphans=()
  _walk "$wt_root"
  return 0
}
_walk() {
  local d
  for d in "$1"/*; do
    [[ -e "$d" || -L "$d" ]] || continue
    if [[ -d "$d" && ! -L "$d" ]]; then
      case "$(classify "$d")" in
        live)     ;;
        ancestor) _walk "$d" ;;
        orphan)   orphans+=("$d") ;;
      esac
    else
      orphans+=("$d")
    fi
  done
}

# ---- anything to do? -------------------------------------------------------
candidates=()
self_idx=-1
for i in "${!paths[@]}"; do
  wt=${paths[$i]}
  [[ "$wt" == "$wt_root"/* ]] || continue                        # not ours
  # The worktree we are standing in cannot be removed from here, but it still
  # gets the merge check — reported, not swept. See the `current` bucket below.
  if [[ -n "$self" && ( "$wt" == "$self" || "$self" == "$wt"/* ) ]]; then
    self_idx=$i
  fi
  candidates+=("$i")
done
collect_orphans
if (( ${#candidates[@]} == 0 && ${#orphans[@]} == 0 )); then
  say "wt-cleanup: nothing to do."
  exit 0
fi

command -v gh >/dev/null || { say "wt-cleanup: gh not on PATH; skipping."; exit 0; }

# Read the default branch locally. `gh repo view` would be a network round trip
# for a fact git already knows. No `gh auth status` probe either: if gh cannot
# reach GitHub, `gh pr list` fails below and nothing gets removed, which is the
# safe direction anyway.
default=$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
default=${default#origin/}
: "${default:=main}"

# Fetching is only worth its ~1s once we know there is something to delete.
fetched=0
ensure_fetch() {
  (( fetched )) && return 0
  git -C "$root" fetch --prune --quiet origin 2>/dev/null
  fetched=1
  return 0
}

# ---- sweep -----------------------------------------------------------------
# removed: gone. held: merged but blocked by local work, so worth mentioning.
# current: this session's own worktree, merged — needs ExitWorktree, not rm.
# kept: nothing to do yet (PR still open) — informational, stays out of the hook.
removed=() held=() current=() kept=()

for i in ${candidates[@]+"${candidates[@]}"}; do
  wt=${paths[$i]} br=${branches[$i]} name=${paths[$i]#$wt_root/}

  if [[ -z "$br" ]]; then
    kept+=("$name: detached HEAD, no branch to check")
    continue
  fi

  # A branch with no remote-tracking ref was never pushed, so it cannot have a
  # PR. This is the common case at session start, and it costs no network.
  if ! git -C "$root" rev-parse --verify --quiet "refs/remotes/origin/$br" >/dev/null; then
    (( i == self_idx )) && continue
    kept+=("$name [$br]: never pushed, no PR to check")
    continue
  fi

  pr=$(gh pr list --head "$br" --state merged --limit 1 --json number -q '.[0].number' 2>/dev/null)
  gh_rc=$?
  if (( gh_rc != 0 )); then
    (( i == self_idx )) && continue
    kept+=("$name [$br]: could not reach GitHub, left alone")
    continue
  fi
  if [[ -z "$pr" ]]; then
    ahead=$(git -C "$root" rev-list --count "origin/$default..$br" 2>/dev/null || echo '?')
    (( i == self_idx )) && continue          # still working in it; say nothing
    kept+=("$name [$br]: no merged PR ($ahead commit(s) not on $default)")
    continue
  fi

  ensure_fetch      # merged: now the network cost is justified

  reasons=()
  dirty=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  (( dirty > 0 )) && reasons+=("$dirty uncommitted file(s)")

  # Our own worktree: merged, but `git worktree remove` cannot pull the rug out
  # from under a running session. Report it so the session can leave properly.
  if (( i == self_idx )); then
    current+=("$name [$br]: PR #$pr is merged and this session is inside it$( (( dirty > 0 )) && printf ' (%s uncommitted file(s) first)' "$dirty" ) — leave it with ExitWorktree(remove)")
    continue
  fi

  if git -C "$root" rev-parse --verify --quiet "refs/remotes/origin/$br" >/dev/null; then
    unpushed=$(git -C "$root" rev-list --count "origin/$br..$br" 2>/dev/null || echo 0)
    (( unpushed > 0 )) && reasons+=("$unpushed unpushed commit(s)")
  fi
  if (( ! force && ${#reasons[@]} )); then
    held+=("$name [$br]: PR #$pr merged, but $(IFS=', '; echo "${reasons[*]}") — inspect it, then rerun with --force")
    continue
  fi

  if command -v tmux >/dev/null && tmux has-session -t "$name" 2>/dev/null; then
    tmux kill-session -t "$name" 2>/dev/null
  fi

  # --force here is safe: the clean/unpushed checks above already ran. It exists
  # so gitignored build output (node_modules/, data/) does not block removal.
  git -C "$root" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"
  # -D, not -d: a squash-merged branch never looks merged to git.
  git -C "$root" branch -D "$br" >/dev/null 2>&1
  note=""
  if git -C "$root" rev-parse --verify --quiet "refs/remotes/origin/$br" >/dev/null; then
    if git -C "$root" push --quiet origin --delete "$br" 2>/dev/null; then
      note=" + remote branch"
    fi
  fi
  removed+=("$name [$br] — PR #$pr$note")
done

# ---- leftovers -------------------------------------------------------------
git -C "$root" worktree prune 2>/dev/null
read_worktrees
collect_wt_paths
collect_orphans
for d in ${orphans[@]+"${orphans[@]}"}; do
  [[ -e "$d" || -L "$d" ]] || continue
  if [[ -d "$d" && ! -L "$d" ]]; then
    rm -rf "$d" && removed+=("${d#$wt_root/} — orphaned directory")
  else
    rm -f "$d" && removed+=("${d#$wt_root/} — stray file")
  fi
done
# Empty parents left behind by removed nested worktrees (e.g. .../feat/).
find "$wt_root" -mindepth 1 -type d -empty -delete 2>/dev/null
# Stale marker/throttle files from the Stop hook.
find "$root/.claude/.wt-state" -type f -mtime +7 -delete 2>/dev/null

# ---- report ----------------------------------------------------------------
if (( hook )); then
  # Silent unless there is something to act on or announce.
  (( ${#removed[@]} == 0 && ${#held[@]} == 0 && ${#current[@]} == 0 )) && exit 0
  summary=""
  (( ${#removed[@]} )) && summary+="removed ${#removed[@]}: $(IFS='; '; echo "${removed[*]}")"
  if (( ${#held[@]} )); then
    [[ -n $summary ]] && summary+=" | "
    summary+="held ${#held[@]}: $(IFS='; '; echo "${held[*]}")"
  fi
  if (( ${#current[@]} )); then
    [[ -n $summary ]] && summary+=" | "
    summary+="current: $(IFS='; '; echo "${current[*]}")"
  fi
  printf 'worktree cleanup — %s\n' "$summary" >> "$root/.claude/wt-cleanup.log"
  python3 - "$summary" <<'PY' 2>/dev/null || true
import json, sys
print(json.dumps({"systemMessage": "worktree cleanup — " + sys.argv[1]}))
PY
  exit 0
fi

printf 'wt-cleanup (%s)\n' "$root"
for r in "${removed[@]:-}"; do [[ -n $r ]] && printf '  removed  %s\n' "$r"; done
for c in "${current[@]:-}"; do [[ -n $c ]] && printf '  current  %s\n' "$c"; done
for h in "${held[@]:-}";    do [[ -n $h ]] && printf '  held     %s\n' "$h"; done
for k in "${kept[@]:-}";    do [[ -n $k ]] && printf '  kept     %s\n' "$k"; done
(( ${#removed[@]} == 0 && ${#held[@]} == 0 && ${#current[@]} == 0 && ${#kept[@]} == 0 )) \
  && printf '  nothing to do\n'
exit 0
