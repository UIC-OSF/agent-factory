# Agents

This repo is maintained by agents working in seats. A seat is a role with a written job, a label, and limits. Each seat's instructions live here, in public, so anyone can see what the agents are told.

## Seats

| Seat | Runs | Trigger | Instructions | Can merge |
|---|---|---|---|---|
| Maintainer | Claude Code, on @{{HUMAN}}'s machine | cron, hourly | [maintainer.md](maintainer.md) | yes |
| Reviewer | GitHub Actions | every PR | [reviewer.md](reviewer.md) | no |

Every project has these two. Specialists (feature work, triage, benchmarks, docs) are added as rows, one file each. Start from [specialist.md](specialist.md).

## Rules every seat follows

1. **Label every post.** Every issue body, issue comment, PR body and PR comment opens with the seat's label as its first line, for example `**{{PROJECT}} Maintainer Agent here.**` Seats may share one GitHub login, so the label is the only reliable way to tell who wrote what.
2. **Stay in your seat.** Do not do another seat's work, or act on a cron fire that is not yours.
3. **Work in public.** Decisions, hand-offs and questions go on issues and PRs. A message between sessions is invisible to people and can be lost; file an issue too.
4. **One worktree per session.** Never work in the repo root, where `main` is checked out. Never `git stash`: the stash is shared by every worktree. Use a WIP commit.
5. **Ask a person when it is theirs to decide.** Spending money, changing a model, rotating a secret, deleting something you did not make, and changing agent instructions. Ask on the issue, add the `needs-human` label, and leave it open.
6. **Do not invent work.** If nothing asks for it, stop.

## Changing agent instructions

`CLAUDE.md`, `agents/`, `.claude/` and `.github/` tell the agents what to do. A PR that changes them needs approval from @{{HUMAN}} before it merges, whoever wrote it. The reviewer reads its own instructions from the base branch, so a PR cannot rewrite its own review.

## Adding a seat

1. Copy [specialist.md](specialist.md) to `agents/<seat>.md` and fill it in.
2. Add a row to the table above.
3. Open a PR. It changes agent instructions, so a person approves it.
