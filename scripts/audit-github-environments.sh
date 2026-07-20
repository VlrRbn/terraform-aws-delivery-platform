#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only verification of GitHub Environment protection rules.

REPOSITORY="${1:-${GITHUB_REPOSITORY:-}}"
GH_BIN="${GH_BIN:-gh}"
REQUIRE_INDEPENDENT_REVIEW="${REQUIRE_INDEPENDENT_REVIEW:-false}"
if [[ ! "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Usage: audit-github-environments.sh OWNER/REPO" >&2
  exit 64
fi

if [[ "$REQUIRE_INDEPENDENT_REVIEW" != "true" && "$REQUIRE_INDEPENDENT_REVIEW" != "false" ]]; then
  echo "REQUIRE_INDEPENDENT_REVIEW must be true or false" >&2
  exit 64
fi

if ! command -v "$GH_BIN" >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "gh and jq are required" >&2
  exit 1
fi

failed=0
repository_json="$("$GH_BIN" api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${REPOSITORY}")"
repository_id="$(jq -r '.id // empty' <<<"$repository_json")"
if [[ ! "$repository_id" =~ ^[0-9]+$ ]]; then
  echo "Unable to resolve numeric repository ID for ${REPOSITORY}" >&2
  exit 1
fi

for environment_name in terraform-dev terraform-stage terraform-prod; do
  environment_json="$("$GH_BIN" api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "repos/${REPOSITORY}/environments/${environment_name}")"

  if ! jq -e '
    any(.protection_rules[]?;
      .type == "required_reviewers"
      and ((.reviewers // []) | length > 0)
    )
  ' <<<"$environment_json" >/dev/null; then
    echo "FAIL ${environment_name}: a required reviewer is not configured" >&2
    failed=1
  elif [[ "$REQUIRE_INDEPENDENT_REVIEW" == "true" ]] && ! jq -e '
    any(.protection_rules[]?;
      .type == "required_reviewers"
      and (.prevent_self_review == true)
      and ((.reviewers // []) | length > 0)
    )
  ' <<<"$environment_json" >/dev/null; then
    echo "FAIL ${environment_name}: independent review requires prevent_self_review=true" >&2
    failed=1
  elif jq -e '
    any(.protection_rules[]?;
      .type == "required_reviewers"
      and (.prevent_self_review == true)
    )
  ' <<<"$environment_json" >/dev/null; then
    echo "PASS ${environment_name}: independent required reviewer"
  else
    echo "PASS ${environment_name}: required reviewer with portfolio self-review allowed"
  fi

  protected_branches="$(jq -r '.deployment_branch_policy.protected_branches // false' <<<"$environment_json")"
  custom_branches="$(jq -r '.deployment_branch_policy.custom_branch_policies // false' <<<"$environment_json")"

  if [[ "$protected_branches" == "true" ]]; then
    echo "PASS ${environment_name}: protected branches only"
  elif [[ "$custom_branches" == "true" ]]; then
    policies_json="$("$GH_BIN" api \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "repos/${REPOSITORY}/environments/${environment_name}/deployment-branch-policies")"
    if jq -e 'any(.branch_policies[]?; .type == "branch" and .name == "main")' <<<"$policies_json" >/dev/null; then
      echo "PASS ${environment_name}: custom main branch policy"
    else
      echo "FAIL ${environment_name}: custom deployment policy does not contain branch main" >&2
      failed=1
    fi
  else
    echo "FAIL ${environment_name}: deployments are not restricted to protected/main branches" >&2
    failed=1
  fi

  target_env="${environment_name#terraform-}"
  expected_secret="TF_APPLY_ROLE_ARN_${target_env^^}"
  secrets_json="$("$GH_BIN" api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "repositories/${repository_id}/environments/${environment_name}/secrets")"
  if jq -e --arg expected "$expected_secret" '
    any(.secrets[]?; .name == $expected)
    and all(.secrets[]?; ((.name | startswith("TF_APPLY_ROLE_ARN_")) | not) or (.name == $expected))
  ' <<<"$secrets_json" >/dev/null; then
    echo "PASS ${environment_name}: only the matching apply-role secret is present"
  else
    echo "FAIL ${environment_name}: expected only matching apply-role secret ${expected_secret}" >&2
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  exit 2
fi

echo "GitHub Environment protection audit passed for ${REPOSITORY}."
