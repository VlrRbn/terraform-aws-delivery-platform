#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mapfile -t action_uses < <(rg -N --no-filename '^[[:space:]]*uses:' "$PROJECT_DIR/.github/workflows" | sed 's/^[[:space:]]*//')
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
