#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mapfile -t action_uses < <(grep -RhE '^[[:space:]]*uses:' "$PROJECT_DIR/.github/workflows" | sed 's/^[[:space:]]*//')
if ((${#action_uses[@]} == 0)); then
  echo "No workflow action uses found" >&2
  exit 1
fi

for action_use in "${action_uses[@]}"; do
  if [[ ! "$action_use" =~ ^uses:[[:space:]]+[^@[:space:]]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]+v[0-9]+$ ]]; then
    echo "Workflow action is not pinned to a full SHA with a reviewed version comment: $action_use" >&2
    exit 1
  fi
done

quality_workflow="$PROJECT_DIR/.github/workflows/terraform-quality-gates.yml"
if [[ "$(grep -c '^  pull_request:$' "$quality_workflow")" -ne 1 ]]; then
  echo "Terraform quality gates must define one pull_request trigger" >&2
  exit 1
fi
if sed -n '/^  pull_request:$/,/^  workflow_dispatch:$/p' "$quality_workflow" | grep -q '^[[:space:]]*paths:'; then
  echo "Terraform quality gates must create a stable check on every pull request" >&2
  exit 1
fi
if [[ "$(grep -c '^[[:space:]]*name: TFLint and Checkov$' "$quality_workflow")" -ne 1 ]]; then
  echo "Terraform quality gates must keep the required check name: TFLint and Checkov" >&2
  exit 1
fi

validate_checkov_pin() {
  local workflow_file="$1"

  if [[ "$(grep -Ec '^[[:space:]]*run: python -m pip install checkov==3\.3\.8$' "$workflow_file")" -ne 1 ]]; then
    echo "Checkov must be installed exactly once at the reviewed version 3.3.8" >&2
    return 1
  fi
}

validate_checkov_pin "$quality_workflow"

unpinned_quality_workflow="$TMP_ROOT/unpinned-terraform-quality-gates.yml"
cp "$quality_workflow" "$unpinned_quality_workflow"
sed -i 's/checkov==3\.3\.8/--upgrade checkov/' "$unpinned_quality_workflow"
if validate_checkov_pin "$unpinned_quality_workflow" >/dev/null 2>&1; then
  echo "Unpinned Checkov negative fixture was not rejected" >&2
  exit 1
fi

promote_workflow="$PROJECT_DIR/.github/workflows/promote.yml"
create_evidence_calls="$(grep -c 'destroy-exception-evidence.sh.*create' "$promote_workflow" || true)"
verify_evidence_calls="$(grep -c 'destroy-exception-evidence.sh.*verify' "$promote_workflow" || true)"
if [[ "$create_evidence_calls" -ne 1 ]]; then
  echo "promote workflow must create destroy exception evidence exactly once" >&2
  exit 1
fi
if [[ "$verify_evidence_calls" -ne 1 ]]; then
  echo "promote workflow must verify destroy exception evidence exactly once" >&2
  exit 1
fi

evidence_writer="$SCRIPT_DIR/destroy-exception-evidence.sh"
test_plan="$TMP_ROOT/tfplan"
test_checksum="$TMP_ROOT/tfplan.sha256"
test_exception="$TMP_ROOT/allow-destroy.json"
test_evidence="$TMP_ROOT/destroy-exception-evidence.json"
test_sha="0123456789abcdef0123456789abcdef01234567"
test_release="guardrail-test-001"

printf '%s\n' 'synthetic reviewed binary plan' > "$test_plan"
sha256sum "$test_plan" > "$test_checksum"
jq -n \
  --arg expires "$(date -u -d '+ 2 days' +%F)" \
  --arg release_id "$test_release" \
  '{
    reason: "Workflow evidence test",
    approved_by: "CHANGE-TEST",
    expires: $expires,
    target_env: "dev",
    release_id: $release_id,
    allowed_addresses: ["module.network.aws_cloudwatch_metric_alarm.old_alarm"]
  }' > "$test_exception"

GITHUB_SHA="$test_sha" TARGET_ENV=dev RELEASE_ID="$test_release" \
  "$evidence_writer" create \
  "$test_plan" "$test_checksum" "$test_exception" \
  policies/approved-destroy/test.json "$test_evidence"

expected_plan_sha="$(sha256sum "$test_plan" | awk '{print $1}')"
expected_exception_sha="$(sha256sum "$test_exception" | awk '{print $1}')"
jq -e \
  --arg github_sha "$test_sha" \
  --arg plan_sha "$expected_plan_sha" \
  --arg exception_sha "$expected_exception_sha" \
  '
    .github_sha == $github_sha
    and .tfplan_sha256 == $plan_sha
    and .exception_sha256 == $exception_sha
    and .target_env == "dev"
    and .release_id == "guardrail-test-001"
  ' "$test_evidence" >/dev/null

GITHUB_SHA="$test_sha" TARGET_ENV=dev RELEASE_ID="$test_release" \
  "$evidence_writer" verify \
  "$test_plan" "$test_checksum" "$test_exception" "$test_evidence"

expect_evidence_failure() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "Destroy exception evidence negative test passed unexpectedly: $name" >&2
    exit 1
  fi
}

printf '%s\n' 'tampered plan content' > "$test_plan"
expect_evidence_failure tampered_plan \
  env GITHUB_SHA="$test_sha" TARGET_ENV=dev RELEASE_ID="$test_release" \
  "$evidence_writer" verify \
  "$test_plan" "$test_checksum" "$test_exception" "$test_evidence"
printf '%s\n' 'synthetic reviewed binary plan' > "$test_plan"

expect_evidence_failure invalid_github_sha \
  env GITHUB_SHA=short TARGET_ENV=dev RELEASE_ID="$test_release" \
  "$evidence_writer" create \
  "$test_plan" "$test_checksum" "$test_exception" \
  policies/approved-destroy/test.json "$TMP_ROOT/invalid-sha.json"

expect_evidence_failure wrong_release_binding \
  env GITHUB_SHA="$test_sha" TARGET_ENV=dev RELEASE_ID=different-release \
  "$evidence_writer" create \
  "$test_plan" "$test_checksum" "$test_exception" \
  policies/approved-destroy/test.json "$TMP_ROOT/wrong-release.json"

altered_evidence="$TMP_ROOT/altered-evidence.json"
jq '.tfplan_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
  "$test_evidence" > "$altered_evidence"
expect_evidence_failure altered_evidence \
  env GITHUB_SHA="$test_sha" TARGET_ENV=dev RELEASE_ID="$test_release" \
  "$evidence_writer" verify \
  "$test_plan" "$test_checksum" "$test_exception" "$altered_evidence"

fake_gh="$TMP_ROOT/fake-gh"
cat >"$fake_gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -Eeuo pipefail

request="${*: -1}"
if [[ "$request" == "repos/example/repository" ]]; then
  jq -n '{id: 123456789}'
elif [[ "$request" == *"/secrets" ]]; then
  target_env="${request#*/environments/terraform-}"
  target_env="${target_env%/secrets}"
  if [[ "${FAKE_GH_MODE:-safe}" == "unsafe" ]]; then
    jq -n '{total_count: 0, secrets: []}'
  else
    jq -n --arg name "TF_APPLY_ROLE_ARN_${target_env^^}" '{total_count: 1, secrets: [{name: $name}]}'
  fi
elif [[ "${FAKE_GH_MODE:-safe}" == "unsafe" ]]; then
  jq -n '{
    protection_rules: [],
    deployment_branch_policy: {protected_branches: false, custom_branch_policies: false}
  }'
else
  prevent_self_review=false
  if [[ "${FAKE_GH_MODE:-safe}" == "independent" ]]; then
    prevent_self_review=true
  fi
  jq -n --argjson prevent_self_review "$prevent_self_review" '{
    protection_rules: [{
      type: "required_reviewers",
      prevent_self_review: $prevent_self_review,
      reviewers: [{type: "User", reviewer: {login: "reviewer"}}]
    }],
    deployment_branch_policy: {protected_branches: true, custom_branch_policies: false}
  }'
fi
FAKE_GH
chmod +x "$fake_gh"

GH_BIN="$fake_gh" "$SCRIPT_DIR/audit-github-environments.sh" example/repository >/dev/null

if REQUIRE_INDEPENDENT_REVIEW=true GH_BIN="$fake_gh" \
  "$SCRIPT_DIR/audit-github-environments.sh" example/repository >/dev/null 2>&1; then
  echo "Portfolio self-review fixture passed independent-review mode" >&2
  exit 1
fi

REQUIRE_INDEPENDENT_REVIEW=true FAKE_GH_MODE=independent GH_BIN="$fake_gh" \
  "$SCRIPT_DIR/audit-github-environments.sh" example/repository >/dev/null

if FAKE_GH_MODE=unsafe GH_BIN="$fake_gh" \
  "$SCRIPT_DIR/audit-github-environments.sh" example/repository >/dev/null 2>&1; then
  echo "Unsafe GitHub Environment fixture was not rejected" >&2
  exit 1
fi

echo "workflow guardrail tests passed"
