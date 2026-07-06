#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
IFS=$'\n\t'

usage() {
  cat >&2 <<'USAGE'
Usage:
  redact-evidence.sh <input-file-or-dir> <output-file-or-dir>

Purpose:
  Create a redacted copy of evidence before sharing it outside a private environment.
  The script preserves enough shape to understand what was masked, but removes exact identifiers.

Examples:
  redact-evidence.sh evidence/raw-run evidence/redacted-run
  redact-evidence.sh /tmp/cloudtrail.json /tmp/cloudtrail.redacted.json

Notes:
  - Text files are redacted and copied.
  - Binary files are skipped by default.
  - Always review output manually before publishing.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

INPUT="${1:-}"
OUTPUT="${2:-}"

if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
  usage
  exit 64
fi
if [[ ! -e "$INPUT" ]]; then
  echo "input does not exist: $INPUT" >&2
  exit 1
fi
if [[ "$INPUT" == "$OUTPUT" ]]; then
  echo "input and output must be different paths" >&2
  exit 64
fi

redact_stream() {
  perl -CSDA -Mstrict -Mwarnings -pe '
    sub keep_tail {
      my ($prefix, $value, $tail_len) = @_;
      $tail_len //= 4;
      my $tail = length($value) > $tail_len ? substr($value, -$tail_len) : $value;
      return $prefix . "xxxxxxxx" . $tail;
    }

    # AWS account IDs: exact value is sensitive; retain field meaning only.
    s/(?<![0-9])\d{12}(?![0-9])/<AWS_ACCOUNT_ID>/g;

    # Common AWS resource IDs: preserve resource type and last chars for correlation.
    s/\bi-([0-9a-f]{8,17})\b/keep_tail("i-", $1, 4)/ge;
    s/\bami-([0-9a-f]{8,17})\b/keep_tail("ami-", $1, 4)/ge;
    s/\bsg-([0-9a-f]{8,17})\b/keep_tail("sg-", $1, 4)/ge;
    s/\bsubnet-([0-9a-f]{8,17})\b/keep_tail("subnet-", $1, 4)/ge;
    s/\bvpc-([0-9a-f]{8,17})\b/keep_tail("vpc-", $1, 4)/ge;
    s/\bvol-([0-9a-f]{8,17})\b/keep_tail("vol-", $1, 4)/ge;
    s/\blt-([0-9a-f]{8,17})\b/keep_tail("lt-", $1, 4)/ge;
    s/\bsnap-([0-9a-f]{8,17})\b/keep_tail("snap-", $1, 4)/ge;
    s/\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/<AWS_ACCESS_KEY_ID>/g;

    # Private and public IPv4 addresses. Keep documentation ranges intact.
    s/\b(10)\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/$1.x.x.x/g;
    s/\b(172)\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}\b/$1.$2.x.x/g;
    s/\b(192\.168)\.\d{1,3}\.\d{1,3}\b/$1.x.x/g;
    s/\b(?!127\.0\.0\.1)(?!0\.0\.0\.0)(?!169\.254\.169\.254)(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b/<IP_ADDRESS>/g;

    # AWS endpoints and generated names that commonly reveal account/project internals.
    s/[A-Za-z0-9.-]+\.elb\.amazonaws\.com/<ALB_DNS_NAME>/g;
    s/[A-Za-z0-9.-]+\.compute(?:-internal)?\.amazonaws\.com/<EC2_DNS_NAME>/g;
    s/[A-Za-z0-9._-]*tfstate[A-Za-z0-9._-]*/<TFSTATE_BUCKET>/g;

    # Emails, URLs with tokens, and obvious secret-like assignments.
    s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<EMAIL>/g;
    s#https://hooks\.slack\.com/services/[A-Za-z0-9/_-]+#<SLACK_WEBHOOK_URL>#g;
    s#(token|secret|password|api[_-]?key)(["\047]?\s*[:=]\s*["\047])[^"\047,\s]+#$1$2<REDACTED>#ig;
  '
}

is_text_file() {
  local path="$1"
  if command -v file >/dev/null 2>&1; then
    file -b --mime "$path" | grep -Eq 'charset=(us-ascii|utf-8)|application/json|application/xml|text/'
  else
    LC_ALL=C grep -Iq . "$path"
  fi
}

redact_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname -- "$dst")"

  if is_text_file "$src"; then
    redact_stream < "$src" > "$dst"
  else
    printf 'Skipped binary file during redaction: %s\n' "$src" > "$dst.skipped"
  fi
}

if [[ -f "$INPUT" ]]; then
  if [[ -d "$OUTPUT" ]]; then
    echo "output must be a file path when input is a file" >&2
    exit 64
  fi
  redact_file "$INPUT" "$OUTPUT"
  echo "redacted file: $OUTPUT"
  exit 0
fi

if [[ -d "$INPUT" ]]; then
  mkdir -p "$OUTPUT"
  input_abs="$(cd -- "$INPUT" && pwd)"
  output_abs="$(mkdir -p "$OUTPUT" && cd -- "$OUTPUT" && pwd)"

  case "$output_abs" in
    "$input_abs"|"$input_abs"/*)
      echo "output directory must not be inside input directory" >&2
      exit 64
      ;;
  esac

  while IFS= read -r -d "" src; do
    rel="${src#"$input_abs"/}"
    redact_file "$src" "$output_abs/$rel"
  done < <(find "$input_abs" -type f -print0)

  echo "redacted directory: $output_abs"
  echo "review output manually before publishing"
  exit 0
fi

echo "input must be a regular file or directory: $INPUT" >&2
exit 64
