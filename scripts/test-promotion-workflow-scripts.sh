#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

expect_failure() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "Promotion workflow negative test passed unexpectedly: $name" >&2
    exit 1
  fi
}

sha=0123456789abcdef0123456789abcdef01234567
repo=example/delivery-platform
run_url="https://github.com/$repo/actions/runs/12345"

# Input validation is fail closed and emits only the selected environment.
input_output="$TMP_ROOT/input-output"
env TARGET_ENV=stage RELEASE_ID=release-001 SOURCE_ENV=dev SOURCE_WORKFLOW_RUN_URL="$run_url" \
  CONFIRM_APPLY=APPLY ALLOW_DESTROY_FILE_INPUT=none GITHUB_REPOSITORY="$repo" GITHUB_OUTPUT="$input_output" \
  "$SCRIPT_DIR/validate-promotion-inputs.sh"
grep -qx 'target_env=stage' "$input_output"
expect_failure wrong_source_env env \
  TARGET_ENV=prod RELEASE_ID=release-001 SOURCE_ENV=dev SOURCE_WORKFLOW_RUN_URL="$run_url" \
  CONFIRM_APPLY=APPLY ALLOW_DESTROY_FILE_INPUT=none GITHUB_REPOSITORY="$repo" GITHUB_OUTPUT="$input_output" \
  "$SCRIPT_DIR/validate-promotion-inputs.sh"
expect_failure wrong_repository_url env \
  TARGET_ENV=stage RELEASE_ID=release-001 SOURCE_ENV=dev \
  SOURCE_WORKFLOW_RUN_URL=https://github.com/exampleXdelivery-platform/actions/runs/12345 \
  CONFIRM_APPLY=APPLY ALLOW_DESTROY_FILE_INPUT=none GITHUB_REPOSITORY="$repo" GITHUB_OUTPUT="$input_output" \
  "$SCRIPT_DIR/validate-promotion-inputs.sh"
expect_failure destroy_path_traversal env \
  TARGET_ENV=dev RELEASE_ID=release-001 SOURCE_ENV=none SOURCE_WORKFLOW_RUN_URL=none \
  CONFIRM_APPLY=APPLY ALLOW_DESTROY_FILE_INPUT=policies/approved-destroy/../unsafe.json \
  GITHUB_REPOSITORY="$repo" GITHUB_OUTPUT="$input_output" "$SCRIPT_DIR/validate-promotion-inputs.sh"

# Source-run metadata comes from the API, then the downloaded manifest is bound to it.
fake_gh="$TMP_ROOT/gh"
cat > "$fake_gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -Eeuo pipefail
jq -n \
  --arg status "${FAKE_RUN_STATUS:-completed}" \
  --arg conclusion success \
  --arg head_sha "$GITHUB_SHA" \
  --arg html_url "$SOURCE_WORKFLOW_RUN_URL" \
  '{status: $status, conclusion: $conclusion, head_sha: $head_sha, html_url: $html_url,
    name: "terraform-promote", path: ".github/workflows/promote.yml", display_title: "promotion"}'
FAKE_GH
chmod +x "$fake_gh"
source_output="$TMP_ROOT/source-output"
env GH_BIN="$fake_gh" GITHUB_REPOSITORY="$repo" GITHUB_SHA="$sha" \
  SOURCE_WORKFLOW_RUN_URL="$run_url" GITHUB_OUTPUT="$source_output" \
  "$SCRIPT_DIR/verify-promotion-source.sh" run
grep -qx 'run_id=12345' "$source_output"
expect_failure incomplete_source_run env FAKE_RUN_STATUS=in_progress GH_BIN="$fake_gh" \
  GITHUB_REPOSITORY="$repo" GITHUB_SHA="$sha" SOURCE_WORKFLOW_RUN_URL="$run_url" \
  GITHUB_OUTPUT="$source_output" "$SCRIPT_DIR/verify-promotion-source.sh" run

manifest="$TMP_ROOT/source-manifest.json"
jq -n --arg sha "$sha" --arg url "$run_url" \
  '{release_id: "release-001", target_env: "dev", commit_sha: $sha, workflow_run_url: $url,
    apply_exitcode: "0", post_apply_exitcode: "0", final_status: "PROMOTABLE"}' > "$manifest"
env RELEASE_ID=release-001 SOURCE_ENV=dev GITHUB_SHA="$sha" SOURCE_WORKFLOW_RUN_URL="$run_url" \
  "$SCRIPT_DIR/verify-promotion-source.sh" manifest "$manifest"
tampered_manifest="$TMP_ROOT/tampered-manifest.json"
jq '.commit_sha = "wrong"' "$manifest" > "$tampered_manifest"
expect_failure tampered_source_manifest env RELEASE_ID=release-001 SOURCE_ENV=dev GITHUB_SHA="$sha" \
  SOURCE_WORKFLOW_RUN_URL="$run_url" "$SCRIPT_DIR/verify-promotion-source.sh" manifest "$tampered_manifest"

# Policy orchestration accepts policy DENY as evidence, but rejects tooling/input failure.
env_root="$TMP_ROOT/env"
mkdir -p "$env_root"
cp "$PROJECT_DIR/policies/tests/safe-plan.json" "$env_root/tfplan.json"
env REPO_ROOT="$PROJECT_DIR" ENV_ROOT="$env_root" TARGET_ENV=dev RELEASE_ID=release-001 SOURCE_ENV=none \
  ALLOW_DESTROY_FILE_INPUT=none GITHUB_SHA="$sha" "$SCRIPT_DIR/run-promotion-policy-gates.sh"
[[ -s "$env_root/policy-results/policy-decision.txt" ]]
[[ -s "$env_root/cost-policy-results/cost-decision.txt" ]]
[[ -s "$env_root/risk-results/risk-decision.json" ]]
rm "$env_root/tfplan.json"
expect_failure missing_plan env REPO_ROOT="$PROJECT_DIR" ENV_ROOT="$env_root" TARGET_ENV=dev \
  RELEASE_ID=release-001 SOURCE_ENV=none ALLOW_DESTROY_FILE_INPUT=none GITHUB_SHA="$sha" \
  "$SCRIPT_DIR/run-promotion-policy-gates.sh"

# Artifact preparation copies the exact plan/config/policy bundle.
cp "$PROJECT_DIR/policies/tests/safe-plan.json" "$env_root/tfplan.json"
printf 'bucket = "test"\n' > "$env_root/backend.hcl"
printf 'project = "test"\n' > "$env_root/terraform.auto.tfvars"
printf 'binary plan\n' > "$env_root/tfplan"
sha256sum "$env_root/tfplan" > "$env_root/tfplan.sha256"
printf 'reviewed plan\n' > "$env_root/tfplan.txt"
artifact_output="$TMP_ROOT/artifact-output"
env REPO_ROOT="$PROJECT_DIR" ENV_ROOT="$env_root" TARGET_ENV=dev RELEASE_ID=release-001 \
  ALLOW_DESTROY_FILE_INPUT=none GITHUB_SHA="$sha" GITHUB_OUTPUT="$artifact_output" \
  "$SCRIPT_DIR/prepare-review-artifact.sh"
grep -qx 'artifact_name=delivery-platform-dev-release-001-plan' "$artifact_output"
sha256sum -c "$env_root/review-artifact/tfplan.sha256" >/dev/null
rm "$env_root/backend.hcl"
expect_failure missing_review_config env REPO_ROOT="$PROJECT_DIR" ENV_ROOT="$env_root" TARGET_ENV=dev \
  RELEASE_ID=release-001 ALLOW_DESTROY_FILE_INPUT=none GITHUB_SHA="$sha" GITHUB_OUTPUT="$artifact_output" \
  "$SCRIPT_DIR/prepare-review-artifact.sh"

# A manifest is promotable only when apply and post-apply drift both succeed.
printf '0\n' > "$env_root/apply_exitcode.txt"
printf '0\n' > "$env_root/post_apply_exitcode.txt"
env REPO_ROOT="$PROJECT_DIR" ENV_ROOT="$env_root" REVIEW_ARTIFACT_DIR="$env_root/review-artifact" \
  TARGET_ENV=dev RELEASE_ID=release-001 SOURCE_ENV=none GITHUB_SHA="$sha" \
  GITHUB_REPOSITORY="$repo" GITHUB_RUN_ID=67890 "$SCRIPT_DIR/write-promotion-manifest.sh"
jq -e '.final_status == "PROMOTABLE" and .apply_exitcode == "0" and .post_apply_exitcode == "0"' \
  "$env_root/promotion-manifest.json" >/dev/null
printf '2\n' > "$env_root/post_apply_exitcode.txt"
env REPO_ROOT="$PROJECT_DIR" ENV_ROOT="$env_root" REVIEW_ARTIFACT_DIR="$env_root/review-artifact" \
  TARGET_ENV=dev RELEASE_ID=release-001 SOURCE_ENV=none GITHUB_SHA="$sha" \
  GITHUB_REPOSITORY="$repo" GITHUB_RUN_ID=67890 "$SCRIPT_DIR/write-promotion-manifest.sh"
jq -e '.final_status == "NOT_PROMOTABLE" and .post_apply_exitcode == "2"' \
  "$env_root/promotion-manifest.json" >/dev/null

echo "promotion workflow script tests passed"
