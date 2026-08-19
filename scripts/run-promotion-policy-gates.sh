#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
: "${TARGET_ENV:?TARGET_ENV is required}"
: "${RELEASE_ID:?RELEASE_ID is required}"
: "${SOURCE_ENV:?SOURCE_ENV is required}"
: "${ALLOW_DESTROY_FILE_INPUT:?ALLOW_DESTROY_FILE_INPUT is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"

root="${ENV_ROOT:-$REPO_ROOT/terraform/envs/$TARGET_ENV}"
plan="$root/tfplan.json"
mkdir -p "$root/policy-results" "$root/cost-policy-results" "$root/risk-results"

destroy_args=()
if [[ "$ALLOW_DESTROY_FILE_INPUT" != "none" ]]; then
  exception_file="$REPO_ROOT/$ALLOW_DESTROY_FILE_INPUT"
  [[ -s "$exception_file" ]] || { echo "Reviewed destroy exception not found: $ALLOW_DESTROY_FILE_INPUT" >&2; exit 64; }
  destroy_args=(ALLOW_DESTROY_FILE="$exception_file")
fi

set +e
env "${destroy_args[@]}" TARGET_ENV="$TARGET_ENV" RELEASE_ID="$RELEASE_ID" OUT_DIR="$root/policy-results" \
  "${SECURITY_POLICY_BIN:-$REPO_ROOT/policies/security-policy.sh}" "$plan" \
  2>&1 | tee "$root/policy-results/policy-output.txt"
policy_ec=${PIPESTATUS[0]}
set -e
echo "$policy_ec" > "$root/policy-results/policy-exitcode.txt"
case "$policy_ec" in 0|2) ;; *) exit "$policy_ec" ;; esac

set +e
OUT_DIR="$root/cost-policy-results" \
  "${COST_POLICY_BIN:-$REPO_ROOT/policies/cost-policy.sh}" "$plan" "$TARGET_ENV" \
  2>&1 | tee "$root/cost-policy-results/cost-policy-output.txt"
cost_ec=${PIPESTATUS[0]}
set -e
echo "$cost_ec" > "$root/cost-policy-results/cost-policy-exitcode.txt"
case "$cost_ec" in 0|2) ;; *) exit "$cost_ec" ;; esac

promotion_args=()
if [[ "$TARGET_ENV" != "dev" ]]; then
  for name in SOURCE_WORKFLOW_RUN_ID SOURCE_WORKFLOW_HEAD_SHA SOURCE_WORKFLOW_CONCLUSION SOURCE_WORKFLOW_NAME SOURCE_WORKFLOW_PATH SOURCE_WORKFLOW_DISPLAY_TITLE SOURCE_WORKFLOW_RUN_URL; do
    [[ -n "${!name:-}" ]] || { echo "$name is required for stage/prod promotion" >&2; exit 64; }
  done
  jq -n \
    --arg release_id "$RELEASE_ID" --arg source_env "$SOURCE_ENV" --arg status passed \
    --arg commit_sha "$GITHUB_SHA" --arg source_workflow_run_url "$SOURCE_WORKFLOW_RUN_URL" \
    --arg source_workflow_run_id "$SOURCE_WORKFLOW_RUN_ID" --arg source_workflow_head_sha "$SOURCE_WORKFLOW_HEAD_SHA" \
    --arg source_workflow_conclusion "$SOURCE_WORKFLOW_CONCLUSION" --arg source_workflow_name "$SOURCE_WORKFLOW_NAME" \
    --arg source_workflow_path "$SOURCE_WORKFLOW_PATH" --arg source_workflow_display_title "$SOURCE_WORKFLOW_DISPLAY_TITLE" \
    '{release_id: $release_id, source_env: $source_env, status: $status, commit_sha: $commit_sha,
      source_workflow_run_url: $source_workflow_run_url, source_workflow_run_id: $source_workflow_run_id,
      source_workflow_head_sha: $source_workflow_head_sha, source_workflow_conclusion: $source_workflow_conclusion,
      source_workflow_name: $source_workflow_name, source_workflow_path: $source_workflow_path,
      source_workflow_display_title: $source_workflow_display_title}' > "$root/promotion-evidence.json"
  cp "$root/promotion-evidence.json" "$root/source-workflow-run-verification.json"
  promotion_args=(PROMOTION_EVIDENCE_FILE="$root/promotion-evidence.json" SOURCE_ENV="$SOURCE_ENV")
fi

set +e
env POLICY_DIR="$root/policy-results" COST_DIR="$root/cost-policy-results" OUT_DIR="$root/risk-results" \
  RELEASE_ID="$RELEASE_ID" "${promotion_args[@]}" \
  "${RISK_CLASSIFIER_BIN:-$REPO_ROOT/policies/risk-classifier.sh}" "$plan" "$TARGET_ENV" \
  2>&1 | tee "$root/risk-results/risk-classifier-output.txt"
risk_ec=${PIPESTATUS[0]}
set -e
echo "$risk_ec" > "$root/risk-results/risk-classifier-exitcode.txt"
case "$risk_ec" in 0|2) ;; *) exit "$risk_ec" ;; esac
