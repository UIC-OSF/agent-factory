# agent-factory

A starting point for open source projects maintained by AI agents, in public.

Every project gets two agents:

- **Maintainer.** A Claude Code session on an hourly loop. It watches issues and PRs, builds fixes, answers review, and merges. It has the final say.
- **Reviewer.** A GitHub Action that reviews every PR adversarially. Its verdict is advice to the maintainer.

Specialist agents (feature work, triage, benchmarks) are added as seats when a project needs them. A person oversees the maintainer and approves every change to agent instructions.

This setup comes from running [equalify-iris](https://github.com/EqualifyEverything/equalify-iris) and [equalify-iris-pdf](https://github.com/EqualifyEverything/equalify-iris-pdf) this way. The goal is a framework to grow a whole agent factory on: automated maintenance of production code.

## Values

Open source, transparent, accessible, plain. Agent instructions are files in the repo, so anyone can read what the agents are told. Decisions happen on issues and PRs. Writing is short.

## Use it

**New project:** click **Use this template** on GitHub, clone the new repo, then:

```sh
scripts/adopt.sh . --project "Name" --repo owner/name --human your-github-login --description "One line."
```

**Existing project:**

```sh
git clone https://github.com/UIC-OSF/agent-factory /tmp/agent-factory
/tmp/agent-factory/scripts/adopt.sh path/to/project --project "Name" --repo owner/name --human your-github-login
```

It never overwrites a file the project already has; it lists them for you to merge.

Then follow [docs/setup.md](docs/setup.md): Bedrock access, the Claude app, branch protection, and starting the maintainer loop.

## What's in it

| Path | What it is |
|---|---|
| `CLAUDE.md` | The project charter every agent reads: who maintains it, and the standards. |
| `agents/` | One file per seat: [maintainer](agents/maintainer.md), its [cron prompt](agents/maintainer-cron.md), [reviewer](agents/reviewer.md), and a [specialist template](agents/specialist.md). |
| `.github/workflows/code-review.yml` | The reviewer. Reads its instructions from the base branch. Always posts a verdict, even when cut off. |
| `.github/workflows/ci.yml` | The required check. |
| `.github/scripts/checks.sh` | The project's checks, shared by CI and the reviewer. |
| `.claude/` | Hooks that give each session its own git worktree and clean it up after merge. |
| `templates/` | The maintainer's local state file, and the project README. |
| `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue forms | Community files, accessibility first. |

## Where this is going

- More seats ported from equalify-iris: duplicate triage, and an issue-to-PR builder.
- A GitHub App identity per seat, instead of a shared login.
- A way to start, watch and renew every project's maintainer from one place.

## License

Copyright (C) 2026 University of Illinois Chicago.

[AGPL-3.0-or-later](LICENSE). You may use, change and share this code. If you change it and run it as a service for others, you must offer them your changed source too.
