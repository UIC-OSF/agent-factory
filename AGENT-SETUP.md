# Agent setup directive

You are an AI agent setting up agent-factory for a person. Follow this file top to bottom. It works for any agent that can run shell commands. Step 7 needs Claude Code.

Your person can start you with:

> Set up agent-factory for me. Follow https://github.com/UIC-OSF/agent-factory/blob/main/AGENT-SETUP.md

## Rules for you

- **Ask before anything outward-facing:** creating a repo, pushing, creating AWS resources, setting secrets, changing repo settings. One confirmation can cover a whole step; say what the step will do first.
- **Ask for what you do not know.** Do not guess names, logins, AWS accounts or regions.
- **Never overwrite a file the person already has.** `adopt.sh` does not; you must not either.
- **Check each step worked** before starting the next. If a step fails, stop, show the error, and say what you think caused it.
- **Write short and plain.** Report each step in one or two lines.
- **Some steps need a browser.** For those, give the person the link and exactly what to click, then wait.

## 0. Gather

Ask for everything still missing, in one message:

| Need | Example | Default |
|---|---|---|
| New repo, or an existing project? | existing: `~/code/thing` | — |
| Project name, as people should see it | `Iris PDF` | — |
| Repo | `UIC-OSF/iris-pdf` | — |
| Public or private | | public |
| One-sentence description | | — |
| GitHub login of the person who oversees the maintainer | `bbertucc` | the logged-in `gh` user |
| AWS profile and region for Bedrock | `dase`, `us-east-2` | `us-east-2` |
| Review model | | `us.anthropic.claude-opus-5` |

Check the tools: `gh auth status`, `aws --version`, `git --version`. `gh` must be logged in as someone with admin on the repo. Ask the person to fix anything missing; do not install tools without asking.

## 1. Get the files

**New repo:**

```sh
gh repo create OWNER/NAME --template UIC-OSF/agent-factory --public --clone   # or --private
cd NAME
scripts/adopt.sh . --project "NAME" --repo OWNER/NAME --human LOGIN --description "SENTENCE"
```

**Existing project:**

```sh
git clone --depth 1 https://github.com/UIC-OSF/agent-factory /tmp/agent-factory
/tmp/agent-factory/scripts/adopt.sh PATH --project "NAME" --repo OWNER/NAME --human LOGIN --description "SENTENCE"
```

A new repo's files can take a few seconds to appear. If the clone is empty, wait 10 seconds and run `git pull`.

If `adopt.sh` lists files it did not overwrite, merge each one by hand. Keep the project's content, add agent-factory's. Show the person each merge before you save it.

## 2. Make it fit the project

1. **Checks.** Read the project to find its build, lint and test commands. Add them to `CHECKS` in `.github/scripts/checks.sh`. If they need a toolchain (Node, Python, ...), add its setup step to both `.github/workflows/ci.yml` and `.github/workflows/code-review.yml`, before the checks run. In `code-review.yml`, give that step `continue-on-error: true`: a failing step there must not stop the review from posting.
2. **Reviewer.** Fill in the two commented sections of `agents/reviewer.md`: what the project's output is and who uses it, and any project-specific blocking items. Read the code to draft them, then show the person.
3. **Dependabot.** Add an entry to `.github/dependabot.yml` for each package ecosystem the project uses.
4. **Worktree seeding.** If the project needs local files to run (`.env`, config), list them in `COPIES` in `.claude/scripts/wt-seed.sh`. List big install dirs in `LINKS`.
5. Run `.github/scripts/checks.sh`. Every line must be `pass` or `skip`. Fix any `fail`.
6. Commit with a short plain message and push. For an existing project, push a branch and open a PR instead of pushing to `main`.

## 3. Bedrock access for the reviewer

Ask first. This creates an IAM role in the person's AWS account. Use their profile: `export AWS_PROFILE=PROFILE`.

```sh
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REPO=OWNER/NAME
ROLE=$(echo "${REPO#*/}" | tr '[:upper:]' '[:lower:]')-bedrock-review

# GitHub's OIDC provider, once per account.
aws iam list-open-id-connect-providers --output text | grep -q token.actions.githubusercontent.com \
  || aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com \
       --client-id-list sts.amazonaws.com

cat > /tmp/trust.json <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow",
 "Principal":{"Federated":"arn:aws:iam::${ACCOUNT}:oidc-provider/token.actions.githubusercontent.com"},
 "Action":"sts:AssumeRoleWithWebIdentity",
 "Condition":{"StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com"},
  "StringLike":{"token.actions.githubusercontent.com:sub":["repo:${REPO}:pull_request","repo:${REPO}:ref:refs/heads/*"]}}}]}
EOF
cat > /tmp/bedrock.json <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow",
 "Action":["bedrock:InvokeModel","bedrock:InvokeModelWithResponseStream"],
 "Resource":["arn:aws:bedrock:*:${ACCOUNT}:inference-profile/*","arn:aws:bedrock:*::foundation-model/anthropic.*"]}]}
EOF
aws iam create-role --role-name "$ROLE" --assume-role-policy-document file:///tmp/trust.json --query Role.Arn --output text
aws iam put-role-policy --role-name "$ROLE" --policy-name bedrock-invoke --policy-document file:///tmp/bedrock.json
rm /tmp/trust.json /tmp/bedrock.json

gh secret set AWS_BEDROCK_ROLE_ARN -R "$REPO" --body "arn:aws:iam::${ACCOUNT}:role/${ROLE}"
gh variable set AWS_REGION -R "$REPO" --body REGION                  # only if not us-east-2
gh variable set BEDROCK_REVIEW_MODEL -R "$REPO" --body MODEL         # only if not the default
```

If the role already exists, show the person its trust policy and ask before changing it.

Check the account can use the model:

```sh
aws bedrock-runtime converse --region REGION --model-id MODEL \
  --messages '[{"role":"user","content":[{"text":"Say ok."}]}]' --query 'output.message.content[0].text'
```

If that is denied, the person must enable the model in the Bedrock console. Give them the link: `https://console.aws.amazon.com/bedrock/home?region=REGION#/modelaccess`.

## 4. The Claude GitHub App (the person does this)

Ask the person to open <https://github.com/apps/claude>, click **Configure**, choose the org, and add this repo. Wait until they say it is done. Step 6 proves it worked.

## 5. Repo settings

Ask first, then:

```sh
REPO=OWNER/NAME
gh label create needs-human -R "$REPO" --color D93F0B --description "Waiting on a person's decision" --force
gh label create accessibility -R "$REPO" --color 5319E7 --description "An accessibility barrier" --force

# main: changes arrive by PR and CI must pass. The review is advice, so it is not required.
gh api -X POST "repos/$REPO/rulesets" --input - <<'EOF'
{"name":"main","target":"branch","enforcement":"active",
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},
 "rules":[
  {"type":"deletion"},{"type":"non_fast_forward"},
  {"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,
    "require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}},
  {"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,
    "required_status_checks":[{"context":"checks"}]}}]}
EOF
```

Rulesets on private repos need a paid GitHub plan. If the call fails for that reason, tell the person and move on.

Who can merge is set by who has write access. Show the person `gh api repos/$REPO/collaborators --jq '.[] | "\(.login) \(.role_name)"'` and suggest write access for the overseer only; others contribute through forks. Do not change access without asking.

## 6. Prove the reviewer works

```sh
git checkout -b try-review origin/main
echo >> CONTRIBUTING.md
git commit -qam "Test the review workflow" && git push -qu origin try-review
gh pr create --fill
```

Wait up to 15 minutes, checking every 2: `gh pr view --json reviews --jq '.reviews[] | .author.login'`. Success is a review from `claude[bot]`. Then close the PR with `--delete-branch`.

If it fails, read the run log (`gh run list --workflow code-review.yml`, then `gh run view ID --log-failed`) and use the table in [docs/getting-started.md](docs/getting-started.md#when-something-is-wrong).

## 7. Start the maintainer

This step needs Claude Code, running on a machine that stays on. If you are not Claude Code, give the person this prompt to paste into Claude Code in the repo, and stop:

> Start the maintainer for this repo. Follow step 7 of https://github.com/UIC-OSF/agent-factory/blob/main/AGENT-SETUP.md

If you are Claude Code but this session was not started inside the repo, ask the person to start Claude Code there and paste that prompt.

If you are Claude Code in the repo:

1. Create the state file: `mkdir -p ~/.claude/agent-state/SLUG` (the repo name, lowercase), then copy `templates/maintainer-state.md` there as `maintainer.md`.
2. Propose a `.claude/settings.local.json` allow list so the loop can run unattended: `Bash(git *)`, `Bash(gh *)`, `Bash(date *)`, `Bash(.github/scripts/checks.sh*)`, plus the project's build and test commands. Show it, and write it only when the person agrees. Never set `bypassPermissions` for them.
3. Enter a worktree (EnterWorktree). Write its path and branch to the state file's LIVE WORKTREE line.
4. Create the recurring cron job with the prompt in `agents/maintainer-cron.md`, at a minute no other job in this session uses. Fill in the state file's CRON line from `date -u`: created now, expires in 7 days.
5. Tell the person:
   - The loop runs only while this session is open.
   - The job expires in 7 days; the state file has the date. Renewing is in `agents/maintainer-cron.md`.
   - To test it, open an issue. Within an hour the maintainer should comment on it.

## 8. Report

End with a short list: what you set up, the repo link, anything skipped and why, and anything still waiting on the person.
