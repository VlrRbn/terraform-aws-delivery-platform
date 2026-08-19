#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
: "${TARGET_ENV:?TARGET_ENV is required}"
: "${RELEASE_ID:?RELEASE_ID is required}"
: "${SOURCE_ENV:?SOURCE_ENV is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"
: "${REVIEW_ARTIFACT_NAME:?REVIEW_ARTIFACT_NAME is required}"
: "${APPLY_ARTIFACT_NAME:?APPLY_ARTIFACT_NAME is required}"

root="${ENV_ROOT:-$REPO_ROOT/terraform/envs/$TARGET_ENV}"
review_dir="${REVIEW_ARTIFACT_DIR:-/tmp/delivery-platform-review-artifact}"
apply_ec=missing
post_apply_ec=missing
[[ -s "$root/apply_exitcode.txt" ]] && apply_ec="$(tr -d '[:space:]' < "$root/apply_exitcode.txt")"
[[ -s "$root/post_apply_exitcode.txt" ]] && post_apply_ec="$(tr -d '[:space:]' < "$root/post_apply_exitcode.txt")"

final_status=NOT_PROMOTABLE
[[ "$apply_ec" == 0 && "$post_apply_ec" == 0 ]] && final_status=PROMOTABLE
tfplan_sha256=missing
[[ -s "$review_dir/tfplan.sha256" ]] && tfplan_sha256="$(awk '{print $1}' "$review_dir/tfplan.sha256")"
security_policy=n/a
cost_policy=n/a
risk=n/a
apply_allowed=n/a
[[ -s "$review_dir/policy-results/policy-decision.txt" ]] && security_policy="$(tr -d '[:space:]' < "$review_dir/policy-results/policy-decision.txt")"
[[ -s "$review_dir/cost-policy-results/cost-decision.txt" ]] && cost_policy="$(tr -d '[:space:]' < "$review_dir/cost-policy-results/cost-decision.txt")"
if [[ -s "$review_dir/risk-results/risk-decision.json" ]]; then
  risk="$(jq -r '.risk // "n/a"' "$review_dir/risk-results/risk-decision.json")"
  apply_allowed="$(jq -r '.apply_allowed // "n/a"' "$review_dir/risk-results/risk-decision.json")"
fi

jq -n \
  --arg release_id "$RELEASE_ID" --arg target_env "$TARGET_ENV" --arg source_env "$SOURCE_ENV" \
  --arg commit_sha "$GITHUB_SHA" --arg workflow_run_url "https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID" \
  --arg workflow_run_id "$GITHUB_RUN_ID" --arg review_artifact "$REVIEW_ARTIFACT_NAME" \
  --arg apply_artifact "$APPLY_ARTIFACT_NAME" --arg tfplan_sha256 "$tfplan_sha256" \
  --arg security_policy "$security_policy" --arg cost_policy "$cost_policy" --arg risk "$risk" \
  --arg apply_allowed "$apply_allowed" --arg apply_exitcode "$apply_ec" --arg post_apply_exitcode "$post_apply_ec" \
  --arg final_status "$final_status" \
  '{release_id: $release_id, target_env: $target_env, source_env: $source_env, commit_sha: $commit_sha,
    workflow_run_url: $workflow_run_url, workflow_run_id: $workflow_run_id, review_artifact: $review_artifact,
    apply_artifact: $apply_artifact, tfplan_sha256: $tfplan_sha256, security_policy: $security_policy,
    cost_policy: $cost_policy, risk: $risk, apply_allowed: $apply_allowed, apply_exitcode: $apply_exitcode,
    post_apply_exitcode: $post_apply_exitcode, final_status: $final_status}' > "$root/promotion-manifest.json"
