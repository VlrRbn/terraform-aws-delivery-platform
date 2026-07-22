# Working With GitHub From The Command Line

This runbook contains the Git and GitHub CLI (`gh`) commands used to operate
`VlrRbn/terraform-aws-delivery-platform`.

## Command Variables

Set the repository once to avoid repeating its name:

```bash
export REPO="VlrRbn/terraform-aws-delivery-platform"
cd /home/leprecha/terraform-aws-delivery-platform
```

The variable exists only in the current shell session.

## GitHub CLI Authentication

Check authentication:

```bash
gh auth status
```

If the token is invalid:

```bash
gh auth login --hostname github.com --git-protocol https --web
```

Open the displayed URL, enter the one-time code, and authorize GitHub CLI.

## Create A Branch And Pull Request

Update `main` before starting new work:

```bash
git switch main
git pull --ff-only
git status --short
```

Create a working branch:

```bash
git switch -c fix/short-description
```

Review and commit the change:

```bash
git diff --check
git status --short
git add path/to/changed-file
git commit \
  -m "fix(ci): short commit subject" \
  -m "Explain why the change is required and what behavior it fixes."
```

Push the branch and open a PR:

```bash
git push -u origin fix/short-description

gh pr create \
  --repo "$REPO" \
  --base main \
  --head fix/short-description \
  --title "fix(ci): short commit subject" \
  --body "Explain why the change is required and what behavior it fixes."
```

Wait for required checks:

```bash
gh pr checks --repo "$REPO" --watch
```

Merge a successful PR and update the local `main` branch:

```bash
gh pr merge \
  --repo "$REPO" \
  --squash \
  --delete-branch

git switch main
git pull --ff-only
```

## Inspect Pull Requests

```bash
gh pr list --repo "$REPO"
gh pr view PR_NUMBER --repo "$REPO"
gh pr diff PR_NUMBER --repo "$REPO"
gh pr checks PR_NUMBER --repo "$REPO" --watch
```

Show failed logs for a workflow run:

```bash
gh run view RUN_ID --repo "$REPO" --log-failed
```

`PR_NUMBER` and `RUN_ID` are placeholders. Replace them with numeric values
from `gh pr list` or `gh run list`.

## Dependabot Pull Requests

List dependency update PRs and inspect a diff:

```bash
gh pr list --repo "$REPO" --label dependencies
gh pr diff PR_NUMBER --repo "$REPO"
```

Ask Dependabot to rebase a branch that is behind `main`:

```bash
gh pr comment PR_NUMBER \
  --repo "$REPO" \
  --body "@dependabot rebase"
```

Check whether the head commit changed:

```bash
gh pr view PR_NUMBER \
  --repo "$REPO" \
  --json headRefOid,mergeStateStatus \
  --jq '{commit: .headRefOid, status: .mergeStateStatus}'
```

Do not merge major Action updates only because Dependabot created the PR.
Review the diff, release notes, and required checks first.

## List Workflows And Runs

```bash
gh workflow list --repo "$REPO"
gh run list --repo "$REPO" --limit 10
```

List runs for a specific workflow:

```bash
gh run list \
  --repo "$REPO" \
  --workflow promote.yml \
  --limit 5
```

Watch a run until it completes:

```bash
gh run watch RUN_ID \
  --repo "$REPO" \
  --exit-status
```

Show failed logs:

```bash
gh run view RUN_ID \
  --repo "$REPO" \
  --log-failed
```

## Promote To Dev

```bash
gh workflow run promote.yml \
  --repo "$REPO" \
  --ref main \
  -f target_env=dev \
  -f release_id=RELEASE_ID \
  -f source_env=none \
  -f source_workflow_run_url=none \
  -f confirm_apply=APPLY \
  -f allow_destroy_file=none
```

After the plan job, GitHub Environment requests manual approval. In GitHub,
select `Review deployments`, select `terraform-dev`, and choose
`Approve and deploy`.

## Promote To Stage

Stage promotion requires the same `release_id` and the successful dev run URL:

```bash
gh workflow run promote.yml \
  --repo "$REPO" \
  --ref main \
  -f target_env=stage \
  -f release_id=RELEASE_ID \
  -f source_env=dev \
  -f source_workflow_run_url="https://github.com/${REPO}/actions/runs/DEV_RUN_ID" \
  -f confirm_apply=APPLY \
  -f allow_destroy_file=none
```

## Promote To Prod

Prod promotion requires the same `release_id` and the successful stage run URL:

```bash
gh workflow run promote.yml \
  --repo "$REPO" \
  --ref main \
  -f target_env=prod \
  -f release_id=RELEASE_ID \
  -f source_env=stage \
  -f source_workflow_run_url="https://github.com/${REPO}/actions/runs/STAGE_RUN_ID" \
  -f confirm_apply=APPLY \
  -f allow_destroy_file=none
```

## Drift Checks

Start a drift check for every environment:

```bash
for env in dev stage prod; do
  gh workflow run drift-check.yml \
    --repo "$REPO" \
    --ref main \
    -f target_env="$env"
done
```

Show the latest three results:

```bash
gh run list \
  --repo "$REPO" \
  --workflow drift-check.yml \
  --limit 3
```

## Workflow Artifacts

List artifact names for a run:

```bash
gh api \
  "repos/${REPO}/actions/runs/RUN_ID/artifacts" \
  --jq '.artifacts[] | [.name, .expired] | @tsv'
```

Download a specific artifact:

```bash
gh run download RUN_ID \
  --repo "$REPO" \
  --name ARTIFACT_NAME \
  --dir /tmp/delivery-platform-artifact
```

Terraform plan and apply artifacts can contain account IDs, ARNs, IP addresses,
and operational metadata. Do not publish them without review and redaction.

## Repository Variables And Secrets

List repository variables:

```bash
gh variable list --repo "$REPO"
```

Read one variable with versions of `gh` that do not provide
`gh variable get`:

```bash
gh variable list \
  --repo "$REPO" \
  --json name,value \
  --jq '.[] | select(.name == "TF_WEB_AMI_ID") | .value'
```

Set a repository variable:

```bash
gh variable set VARIABLE_NAME \
  --repo "$REPO" \
  --body "VARIABLE_VALUE"
```

Set an environment secret without placing the value in shell history:

```bash
read -rsp "Secret value: " SECRET_VALUE
echo
printf '%s' "$SECRET_VALUE" | gh secret set SECRET_NAME \
  --repo "$REPO" \
  --env terraform-dev
unset SECRET_VALUE
```

The GitHub API returns secret names and metadata, never secret values.

## Audit GitHub Environments

The portfolio/lab mode allows self-review but still requires a manual reviewer,
an environment-specific apply-role secret, and deployment only from `main`:

```bash
./scripts/audit-github-environments.sh "$REPO"
```

Use strict mode for a team or production-like deployment:

```bash
REQUIRE_INDEPENDENT_REVIEW=true \
  ./scripts/audit-github-environments.sh "$REPO"
```

## Quick Diagnostics

```bash
gh auth status
git status --short
git branch --show-current
gh pr list --repo "$REPO"
gh run list --repo "$REPO" --limit 5
```

Common errors:

- `HTTP 404 ... runs/RUN_ID`: replace the `RUN_ID` placeholder with a real ID.
- `Required input 'target_env' not provided`: add `-f target_env=dev`.
- Invalid GitHub token: repeat `gh auth login`.
- Failed workflow: use `gh run view RUN_ID --log-failed`.
- `BLOCKED` PR: inspect required checks and whether the branch is behind `main`.

## Safety Boundaries

- Do not pass AWS credentials or secret values through CLI arguments.
- Do not use `--admin` to bypass branch protection without an incident reason.
- Do not merge PRs with failed or pending checks.
- Do not run `promote.yml` without reviewing the plan artifact.
- `confirm_apply=APPLY` does not bypass GitHub Environment approval or policy gates.
- `gh workflow run` creates a workflow run; it is not a read-only command.
