---
description: Remove Claude Code worktrees whose PR has merged (branches, remote branches, leftover dirs)
allowed-tools: Bash(.claude/scripts/wt-cleanup.sh:*), Bash(git status:*), Bash(git log:*), Bash(git diff:*), ExitWorktree
---

Run `.claude/scripts/wt-cleanup.sh $ARGUMENTS` and report what it did, then act
on the two lines it cannot handle by itself:

- a `current` line means this session is sitting in a worktree whose PR has
  merged. Show me anything uncommitted in it, and once I confirm there is
  nothing to save, leave and delete it with ExitWorktree (`action: "remove"`).
- a `held` line means a merged worktree was left alone because of uncommitted or
  unpushed work. Show me what is in it before suggesting `--force`.

Do not remove a worktree whose PR is still open, whatever it looks like.
