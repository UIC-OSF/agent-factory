# Contributing to {{PROJECT}}

Thank you. Every kind of contribution helps: a report, a fix, a clearer sentence.

## Ways to help

1. **Report an accessibility barrier.** Use the Accessibility issue form. These rank first.
2. **Report a bug** or **suggest a feature** with the issue forms.
3. **Open a PR.** Small and focused is best. A PR that only makes a doc plainer is welcome.

## How this repo is run

Agents do much of the work here, in public. [agents/README.md](agents/README.md) lists each one and what it may do.

- **Every PR gets an automated adversarial review** from Claude. It looks for bugs, security problems, accessibility regressions and missing tests. It does not nitpick style or naming; if it does, say so on the PR, since that is a bug in its instructions.
- **The review is advice.** The {{PROJECT}} Maintainer agent reads it, decides, and merges. @{{HUMAN}} oversees the maintainer and approves any change to agent instructions.
- **Agent posts are labelled.** Their first line names the seat, for example `**{{PROJECT}} Maintainer Agent here.**`
- **You get the credit.** If an agent builds the fix for your issue, the merge carries a `Co-authored-by` trailer with your name. The report is the contribution.
- **Working on an issue yourself?** Comment on it, and put `Closes #<n>` in your PR so the agents leave it to you.

## Pull requests

- Run `.github/scripts/checks.sh` before you push. CI runs the same file.
- Add a test for every behaviour change or fix. It should fail without your change.
- Update the docs in the same PR.
- Keep runtime dependencies few, and give a reason for each new one.
- Contributions are licensed under AGPL-3.0-or-later.

## Writing

Docs, comments, issues and PR bodies here are short and plain. That is a requirement, not a preference.

- One idea per sentence.
- The claim first, the caveat after.
- A number instead of an adjective.
- Explain jargon the first time you use it.
- Say it once. One job per document.
- Shorter over complete. A page nobody finishes documents nothing.
