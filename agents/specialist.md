<!-- Copy to agents/<seat>.md, fill it in, delete this comment, and add the seat to the table in agents/README.md. -->

# <Seat name>

Label: `**{{PROJECT}} <Seat name> Agent here.**`

## Job

<!-- One or two sentences. What this seat produces, and for whom. -->

## Runs

<!-- Where and when: a Claude Code cron in a local session, or a GitHub Actions workflow. Name the trigger and the cron minute, if any. -->

## Hands off to

The Maintainer. This seat opens PRs or issues; the Maintainer reviews and merges them. <!-- Say how: label, branch prefix, or issue title. -->

## May

<!-- The tools and actions it needs, and nothing more. -->

## May not

- Merge anything.
- Change `CLAUDE.md`, `agents/`, `.claude/` or `.github/` except by a PR a person approves.
- Spend money beyond <!-- limit --> without asking on an issue first.
- Act on a cron fire that is not its own.

## Done when

<!-- How this seat knows a task is finished, and what it does when there is nothing to do. Default: say so in one line and stop. -->
