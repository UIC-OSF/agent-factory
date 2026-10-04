#!/usr/bin/env bash
# SessionStart hook. A fresh worktree holds only what git tracks, so it has none
# of the local files needed to run anything. Seed them:
#
#   LINKS   symlinked to the main checkout (big install dirs: no re-download)
#   COPIES  copied (local config the app needs to start)
#
# Do not seed local databases or data dirs: a branch should not be able to
# write to the real one.
#
# Everything here must stay invisible to `git status` (list it in .gitignore),
# or the cleanup and auto-exit hooks read the worktree as dirty and leave it.
set -uo pipefail

LINKS=(node_modules)
COPIES=(.env)

payload=$(cat 2>/dev/null || true)
cwd=$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("cwd") or "")
except Exception:
    print("")' 2>/dev/null)
[[ -n "$cwd" ]] || cwd=$PWD
[[ -d "$cwd" ]] || exit 0

common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
root=${common%/.git}
self=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ "$self" == "$root/.claude/worktrees/"* ]] || exit 0     # only seed worktrees
[[ "$self" != "$root" ]] || exit 0

seeded=()

for d in "${LINKS[@]}"; do
  [[ -e "$self/$d" || -L "$self/$d" ]] && continue         # already there
  [[ -d "$root/$d" ]] || continue                          # nothing to link to
  ln -s "$root/$d" "$self/$d" 2>/dev/null && seeded+=("$d (linked)")
done

for f in "${COPIES[@]}"; do
  [[ -e "$self/$f" ]] && continue
  [[ -f "$root/$f" ]] || continue
  cp -p "$root/$f" "$self/$f" 2>/dev/null && seeded+=("$f (copied)")
done

(( ${#seeded[@]} )) || exit 0

python3 - "${seeded[@]}" <<'PY' 2>/dev/null || true
import json, sys
print(json.dumps({"systemMessage": "worktree ready — " + ", ".join(sys.argv[1:])}))
PY
exit 0
