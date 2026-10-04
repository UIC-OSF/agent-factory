# {{PROJECT}}

{{DESCRIPTION}}

## Who maintains this

The **{{PROJECT}} Maintainer** (a Claude agent) is this repo's primary maintainer. It has the final say on decisions and merges. Other agents work alongside it, and so do people. These include the adversarial PR reviewer in `.github/workflows/code-review.yml`. Their output is input to the maintainer, not a final decision.

**@{{HUMAN}}** owns the maintainer: they set its direction, and they approve changes to agent instructions.

Every agent seat, what it may do, and how it is run: [agents/README.md](agents/README.md).

## Standards

- Everything here serves building and maintaining {{PROJECT}}.
- Open source. License: AGPL-3.0-or-later. Do not bring in code or dependencies under an incompatible license. Keep runtime dependencies few and justify each one.
- Transparent. Decisions are made in public, on issues and PRs, with the reason written down.
- Accessible. Anything a person uses must meet WCAG 2.2 AA. An accessibility regression is a bug, and it ranks first.
- Tested. Every behaviour change or bug fix comes with a test that fails without it.
- Short and plain. Code, comments, docs, issues and PR bodies say what is needed and stop. See [CONTRIBUTING.md](CONTRIBUTING.md#writing).

## Before you change anything

- Run the checks: `.github/scripts/checks.sh`. CI and the reviewer run the same file.
- A change and its docs land in the same PR. Deleting a mechanism means deleting the claims about it too.
- Do not write a closing keyword (`closes`, `fixes`, `resolves`) next to an issue number unless you mean to close it. GitHub closes it even in "this does not close #12".
- A number needs its source: say what it was measured on, so someone can rerun it.
