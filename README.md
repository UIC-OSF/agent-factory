# UIC OSF's AI-Powered Software Factory Building Blocks

A starting point for open source projects maintained by AI agents, in public.

Every project gets three agents:

- **Triage.** A GitHub Action that reads each new issue, labels it, asks the reporter for anything missing, and tags the owners when it is ready.
- **Maintainer.** A Claude Code session on an hourly loop, with its own GitHub account. It works on the issues an owner assigns it: builds the fix, answers review, and merges. On that work, it has the final say.
- **Reviewer.** A GitHub Action that reviews every PR adversarially. Its verdict is advice to the maintainer.

People stay in charge. Owners choose what gets worked on, approve risky changes, and can stop every agent with one switch. These [safety rails](agents/rails.md) are enforced by GitHub where it can.

Specialist agents (feature work, benchmarks, docs) are added as seats when a project needs them.

This setup comes from running [equalify-iris](https://github.com/EqualifyEverything/equalify-iris) and [equalify-iris-pdf](https://github.com/EqualifyEverything/equalify-iris-pdf) this way. The goal is a framework to grow a whole AI-Powered Software Factory on: automated maintenance of production code.

## Values

Open source, transparent, accessible, plain. Agent instructions are files in the repo, so anyone can read what the agents are told. Decisions happen on issues and PRs. Writing is short.

## Use it

**Easiest:** ask your AI agent. It works out the rest and asks you for what it needs:

> Set up UIC OSF's AI-Powered Software Factory Building Blocks for me. Follow https://github.com/UIC-OSF/agent-factory/blob/main/AGENT-SETUP.md

**By hand, new project:** click **Use this template** on GitHub, clone the new repo, then:

```sh
scripts/adopt.sh . --project "Name" --repo owner/name --human your-github-login --maintainer agent-login --description "One line."
```

**By hand, existing project:**

```sh
git clone https://github.com/UIC-OSF/agent-factory /tmp/agent-factory
/tmp/agent-factory/scripts/adopt.sh path/to/project --project "Name" --repo owner/name --human your-github-login --maintainer agent-login
```

It never overwrites a file the project already has; it lists them for you to merge.

Then follow [docs/getting-started.md](docs/getting-started.md): Bedrock access, the Claude app, access and branch rules, a test PR, and starting the maintainer.

## What's in it

| Path | What it is |
|---|---|
| `AGENT-SETUP.md` | Step-by-step setup for an AI agent to follow. |
| `CLAUDE.md` | The project charter every agent reads: who maintains it, and the standards. |
| `agents/` | One file per seat: [triage](agents/triage.md), [maintainer](agents/maintainer.md) and its [cron prompt](agents/maintainer-cron.md), [reviewer](agents/reviewer.md), and a [specialist template](agents/specialist.md). The [safety rails](agents/rails.md) and their values ([rails.conf](agents/rails.conf)). |
| `.github/workflows/code-review.yml` | The reviewer. Reads its instructions from the base branch. Always posts a verdict, even when cut off. |
| `.github/workflows/issue-triage.yml` | The triage agent. The model has no shell; a script checks its answer and posts it. |
| `.github/workflows/ci.yml` | The required `checks` check. |
| `.github/workflows/rails.yml` | The required `rails` check: PR size and the off switch. Runs from the base branch. |
| `.github/scripts/checks.sh` | The project's checks, shared by CI and the reviewer. |
| `.claude/` | Hooks that give each session its own git worktree and clean it up after merge. |
| `templates/` | The maintainer's local state file, and the project README. |
| `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue forms | Community files, accessibility first. |

## Where this is going

- More seats ported from equalify-iris: an issue-to-PR builder.
- A GitHub App per seat, instead of a machine account.
- A way to start, watch and renew every project's maintainer from one place.

## License

Copyright (C) 2026 University of Illinois Chicago.

[AGPL-3.0-or-later](LICENSE). You may use, change and share this code. If you change it and run it as a service for others, you must offer them your changed source too.
