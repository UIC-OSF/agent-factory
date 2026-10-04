# Setup

One-time steps for a repo that uses agent-factory. Do them in order. About 30 minutes.

## 1. Fill in the placeholders

```sh
scripts/adopt.sh . --project "Name" --repo owner/name --human your-github-login --description "One line."
```

Then edit the two sections marked with comments in `agents/reviewer.md`, and the `CHECKS` list in `.github/scripts/checks.sh`.

## 2. Bedrock access for the reviewer

The review workflow calls Claude on AWS Bedrock through GitHub's OIDC. No long-lived keys.

1. In IAM, add GitHub as an identity provider if the account does not have it: `token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
2. Create a role with this trust policy (replace `OWNER/NAME` and the account ID):

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

3. Give it `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` on the model's inference profile and the foundation models behind it. A `us.` cross-region profile can route to us-east-1, us-east-2 and us-west-2, so allow all three.
4. In the repo's settings, add the secret `AWS_BEDROCK_ROLE_ARN`. Optional variables: `BEDROCK_REVIEW_MODEL` (default `us.anthropic.claude-opus-5`) and `AWS_REGION` (default `us-east-2`).

## 3. The Claude GitHub App

Install it on the repo: <https://github.com/apps/claude>. Reviews then post as `claude[bot]`.

## 4. Protect `main`

In a branch ruleset for `main`:

- Require a pull request.
- Require the `checks` status check (from `ci.yml`). Do not require the review: it is advice.
- Restrict who can push to `main` to @{{HUMAN}}; that includes merging. The maintainer agent works under that login.
- Do not require code-owner approval. GitHub does not let anyone approve their own PR, so it would block the maintainer.

## 5. Labels

```sh
gh label create needs-human --color D93F0B --description "Waiting on a person's decision"
gh label create accessibility --color 5319E7 --description "An accessibility barrier"
```

## 6. Start the maintainer

On the machine that will run it:

1. `mkdir -p ~/.claude/agent-state/{{SLUG}}` and copy `templates/maintainer-state.md` there as `maintainer.md`.
2. Start Claude Code in the repo with `claude --worktree`, and give the worktree path to the state file's LIVE WORKTREE line.
3. Create the cron job: [agents/maintainer-cron.md](../agents/maintainer-cron.md).

The loop runs while that session is open. It needs to run `git` and `gh` unattended, so allow them in `.claude/settings.local.json` (not committed). Allow only what it needs.
