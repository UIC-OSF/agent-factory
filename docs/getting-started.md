# Getting started with UIC OSF's AI-Powered Software Factory Building Blocks

From nothing to a project where agents triage issues, review PRs, and build the work its owners assign. About 45 minutes, most of it AWS.

**Faster:** ask your AI agent to do it. It runs every step it can and tells you what it needs from you:

> Set up UIC OSF's AI-Powered Software Factory Building Blocks for me. Follow https://github.com/UIC-OSF/agent-factory/blob/main/AGENT-SETUP.md

## What you need

- Admin on the GitHub org the repo will live in.
- The `gh` CLI, logged in: `gh auth status`.
- An AWS account with Bedrock, and permission to create IAM roles.
- A GitHub account for the maintainer agent, separate from yours, for example `yourname-agent`. GitHub allows one free machine account per person. It is how GitHub tells you and the agent apart, which is what makes the [safety rails](../agents/rails.md) enforceable.
- Claude Code, on the machine that will run the maintainer. It runs only while that session is open, so use a machine that stays on.

## 1. Make the repo

New project:

```sh
gh repo create OWNER/NAME --template UIC-OSF/agent-factory --public --clone
cd NAME
scripts/adopt.sh . --project "Name" --repo OWNER/NAME --human your-github-login --maintainer agent-login --description "One plain sentence."
```

Existing project: see [Use it](https://github.com/UIC-OSF/agent-factory#use-it) in the README. `adopt.sh` lists any files it did not overwrite; merge those by hand.

Then make it yours:

1. In `agents/reviewer.md`, fill in the two commented sections: what the project is, and any project-specific blocking items.
2. In `.github/scripts/checks.sh`, add your build and test commands to `CHECKS`. If they need a toolchain, add its setup step to `.github/workflows/ci.yml` and `code-review.yml`.
3. Run `.github/scripts/checks.sh`. It should end with every check `pass` or `skip`.
4. Commit and push to `main`.

## 2. Give the reviewer and triage Bedrock access

The review and triage workflows call Claude on AWS Bedrock. GitHub proves who it is with OIDC, so no AWS keys are stored.

1. **Model access.** In the Bedrock console, check that the account can use the Anthropic model you want. Default: `us.anthropic.claude-opus-5`.
2. **Identity provider.** In IAM, add GitHub if the account does not have it yet: provider `token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
3. **Role.** Create a role with this trust policy. Replace `ACCOUNT_ID` and `OWNER/NAME`:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": { "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
         "StringLike": { "token.actions.githubusercontent.com:sub": [
           "repo:OWNER/NAME:pull_request",
           "repo:OWNER/NAME:ref:refs/heads/*"
         ]}
       }
     }]
   }
   ```

4. **Permissions.** Allow `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` on the inference profile and the models behind it. A `us.` profile can route to us-east-1, us-east-2 and us-west-2, so allow all three.
5. **Repo settings → Secrets and variables → Actions:**
   - secret `AWS_BEDROCK_ROLE_ARN`: the role's ARN.
   - variable `AWS_REGION` (optional): default `us-east-2`.
   - variable `BEDROCK_REVIEW_MODEL` (optional): default `us.anthropic.claude-opus-5`.

## 3. Install the Claude GitHub App

Install <https://github.com/apps/claude> on the repo. Reviews then post as `claude[bot]`.

## 4. Access and `main`

Access, under Settings → Collaborators:

- Owners: **Admin**.
- The maintainer's account: **Write**. Never admin: admins can bypass the rules below. Accept the invite from that account.
- Everyone else contributes through forks.

Settings → Rules → new branch ruleset for `main`:

- Require a pull request, with **Require review from Code Owners** on. That is what makes risky files in `.github/CODEOWNERS` need an owner's approval.
- Require the status checks `checks` (from `ci.yml`) and `rails` (from `rails.yml`). Do not require the review: it is advice to the maintainer.
- Bypass list: the Repository admin role, "for pull requests only". An owner can then merge their own change to a risky file, since GitHub does not let anyone approve their own PR.
- Rulesets on private repos need a paid GitHub plan.

## 5. Add labels

```sh
gh label create needs-human --color D93F0B --description "Waiting on a person's decision"
gh label create accessibility --color 5319E7 --description "An accessibility barrier"
gh label create needs-info --color FBCA04 --description "Triage asked the reporter for more"
gh label create triaged --color 0E8A16 --description "Ready for an owner to assign"
gh label create large-ok --color C5DEF5 --description "An owner allows this PR over the size limit"
```

## 6. Check the reviewer works

```sh
git checkout -b try-review
echo "" >> CONTRIBUTING.md
git commit -am "Test the review workflow" && git push -u origin try-review
gh pr create --fill
gh pr checks --watch
```

Within about 10 minutes the PR should have a review from `claude[bot]` ending in `Accessibility impact: …`. Close the PR and delete the branch when it does. If it doesn't, see [When something is wrong](#when-something-is-wrong).

## 7. Start the maintainer

On a machine that stays on. Use a clone just for the agent, so it never acts as you:

1. Make a fine-grained token on the maintainer's account (Settings → Developer settings → Fine-grained tokens). Resource owner: the repo's org. Only this repo. Permissions: Contents, Issues and Pull requests read and write; Actions and Variables read. The org may need to approve it.
2. Clone and set the agent's identity:

   ```sh
   git clone https://github.com/OWNER/NAME ~/agents/NAME && cd ~/agents/NAME
   git config user.name agent-login
   git config user.email agent-login@users.noreply.github.com
   git config credential.https://github.com.helper '!gh auth git-credential'
   ```

3. Create the state file:

   ```sh
   mkdir -p ~/.claude/agent-state/SLUG   # SLUG: the repo name, lowercase
   cp templates/maintainer-state.md ~/.claude/agent-state/SLUG/maintainer.md
   ```

4. Create `.claude/settings.local.json`. It is git-ignored, so the token stays on this machine. It gives the agent its own token and lets it run `git` and `gh` without asking, minus the commands no agent needs:

   ```json
   {
     "env": { "GH_TOKEN": "the token from step 1" },
     "permissions": {
       "allow": ["Bash(git *)", "Bash(gh *)", "Bash(date *)", "Bash(.github/scripts/checks.sh*)"],
       "deny": ["Bash(gh secret *)", "Bash(gh variable set *)", "Bash(gh variable delete *)",
                "Bash(gh repo delete *)", "Bash(gh repo edit *)", "Bash(gh auth *)",
                "Bash(gh pr merge * --admin*)", "Bash(git push --force*)", "Bash(git push * --force*)",
                "Bash(git push -f*)", "Bash(git push * -f*)"]
     }
   }
   ```

   Add your build and test commands to `allow`. Check it worked: `claude -p 'run gh api user --jq .login'` prints the agent's login.

5. Start a session in its own worktree: `claude --worktree`. Put the worktree's path in the state file's LIVE WORKTREE line.
6. Start the loop. Ask the session to create the cron job in [agents/maintainer-cron.md](../agents/maintainer-cron.md), then fill in the CRON line of the state file.
7. To test it, open an issue. Triage should comment within a few minutes. Assign the issue to the agent's account; within an hour the maintainer should comment, with `**Name Maintainer Agent here.**` as its first line.

Every 7 days the cron job expires. The state file has the date; renew the job before then.

## When something is wrong

| What you see | Likely cause |
|---|---|
| No review, and the workflow says it skipped itself | The Claude App is not installed. Or the PR changes `code-review.yml`: that PR's review posts as `github-actions[bot]` instead. Or GitHub Actions is down: check githubstatus.com. |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The trust policy's `OWNER/NAME` does not match the repo exactly, or the OIDC provider is missing. |
| `AccessDeniedException` from Bedrock | The model is not enabled in the account, or the role lacks one of the three regions. |
| A review titled "Automated review did not complete" | The model ran out of time. Re-run it: `gh workflow run code-review.yml -f pr_number=N`. |
| No review on a fork's PR | Forks get no secrets, so they are skipped. Read the diff, then re-run with the command above. |
| The maintainer stopped commenting | Its cron job expired, or its session closed. Check the state file's CRON and LAST CHECKED lines. Or `AGENTS_PAUSED` is set. |
| The maintainer ignores an issue | It works only on issues an owner assigned to it. Check the assigner is listed in `agents/rails.conf`. |
| The `rails` check fails | The PR is over the size limit (split it, or an owner adds `large-ok`), or the agents are paused. Its log says which. |
| No triage comment | The repo variable `AGENTS_PAUSED` is `true`, or Bedrock access is missing (see above). |
