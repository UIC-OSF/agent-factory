# UIC OSF's AI-Powered Software Factory Building Blocks

A template for open source projects maintained by AI agents, in public, with people in charge.

## Get started

Paste this into your AI agent (Claude Code, or any agent that can run commands):

```text
Set up UIC OSF's AI-Powered Software Factory Building Blocks for me. Follow https://github.com/UIC-OSF/software-factory-blocks/blob/main/AGENT-SETUP.md
```

It asks whether this is a new repo or an existing project, does every step it can, and tells you what it needs from you. About 45 minutes.

**What you need first:**

- Admin on the GitHub org for the repo.
- An AWS account with Bedrock.
- A second GitHub account for the maintainer agent, for example `yourname-agent`.
- A machine that stays on, with Claude Code, to run the maintainer.

Prefer to do it yourself? Follow the [getting-started guide](docs/getting-started.md).

## How it works

Every project gets three agents:

| Agent | Runs | Does |
|---|---|---|
| **Triage** | GitHub Actions | Labels each new issue, asks for missing details, and tags the owners when it is ready. |
| **Maintainer** | Claude Code, hourly, as its own GitHub account | Builds the issues an owner assigns it, answers review, and merges. |
| **Reviewer** | GitHub Actions | Reviews every PR adversarially. Its verdict is advice to the maintainer. |

An issue goes from report to merge like this:

1. Someone opens an issue.
2. Triage gets it ready and tags the owners.
3. An owner assigns it to the maintainer. Nothing starts without this.
4. The maintainer opens a PR, and the reviewer reviews it.
5. The maintainer merges.

People stay in charge. Owners choose the work, approve risky changes, and can stop every agent with one switch. These [safety rails](agents/rails.md) are enforced by GitHub where it can.

Add more agents (feature work, benchmarks, docs) as a project needs them: [agents/specialist.md](agents/specialist.md).

## Values

- **Open source.** AGPL-3.0-or-later.
- **Transparent.** Agent instructions are files in the repo, and decisions happen on issues and PRs.
- **Accessible.** WCAG 2.2 AA. An accessibility regression ranks first.
- **Plain.** Short writing that says what is needed and stops.

## What's in it

| Path | What it is |
|---|---|
| [`AGENT-SETUP.md`](AGENT-SETUP.md) | Setup steps for an AI agent to follow. |
| [`docs/getting-started.md`](docs/getting-started.md) | The same setup, for a person. |
| [`CLAUDE.md`](CLAUDE.md) | The charter every agent reads: who maintains the project, and the standards. |
| [`agents/`](agents/README.md) | One file per agent, and the [safety rails](agents/rails.md). |
| `.github/workflows/` | Triage, review, CI (`checks`) and the `rails` check. |
| `.github/scripts/checks.sh` | The project's checks, shared by CI and the reviewer. |
| `.claude/` | Hooks that give each agent session its own git worktree. |
| `scripts/adopt.sh` | Copies the template into a project and fills in its names. Never overwrites a file. |

## Where this is going

This setup comes from running [equalify-iris](https://github.com/EqualifyEverything/equalify-iris) and [equalify-iris-pdf](https://github.com/EqualifyEverything/equalify-iris-pdf) this way. The goal is a whole AI-Powered Software Factory: automated maintenance of production code. Next:

- An issue-to-PR builder, ported from equalify-iris.
- A GitHub App per agent, instead of a second account.
- One place to start, watch and renew every project's maintainer.

## License

Copyright (C) 2026 University of Illinois Chicago.

[AGPL-3.0-or-later](LICENSE). You may use, change and share this code. If you change it and run it as a service for others, you must offer them your changed source too.
