#!/usr/bin/env bash
set -Eeuo pipefail

# Why this exists:
# - backend.hcl and terraform.tfvars are intentionally ignored by git;
# - GitHub Actions runners start from a clean checkout and cannot rely on local files;
# - CI should build temporary config from GitHub Variables/Secrets and upload only
#   reviewed operational artifacts.
#
# The script writes:
# - backend.hcl: S3 backend config for the selected environment;
# - terraform.auto.tfvars: non-secret Terraform inputs used by plan/apply.
#
# Required environment variables:
# - TF_STATE_BUCKET
# - TF_WEB_AMI_ID
# - TF_SSM_PROXY_AMI_ID
#
# Optional environment variables:
# - AWS_REGION, default eu-west-1
# - TF_ENV_DIR, default terraform/envs/<target_env>

usage() {
  cat >&2 <<'USAGE'
Usage:
  write-terraform-env-files.sh <dev|stage|prod>

Example:
  AWS_REGION=eu-west-1 \
  TF_STATE_BUCKET=my-tfstate-bucket \
  TF_WEB_AMI_ID=ami-0123456789abcdef0 \
  TF_SSM_PROXY_AMI_ID=ami-0123456789abcdef0 \
  write-terraform-env-files.sh dev
USAGE
}

TARGET_ENV="${1:-}"
case "$TARGET_ENV" in
  dev|stage|prod) ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 64 ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENV_DIR="${TF_ENV_DIR:-${PROJECT_DIR}/terraform/envs/${TARGET_ENV}}"

AWS_REGION="${AWS_REGION:-eu-west-1}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-}"
TF_WEB_AMI_ID="${TF_WEB_AMI_ID:-}"
TF_SSM_PROXY_AMI_ID="${TF_SSM_PROXY_AMI_ID:-}"
prod_teardown_mode_line=""

if [[ -z "$TF_STATE_BUCKET" ]]; then
  echo "TF_STATE_BUCKET is required" >&2
  exit 64
fi
if [[ -z "$TF_WEB_AMI_ID" ]]; then
  echo "TF_WEB_AMI_ID is required" >&2
  exit 64
fi
if [[ -z "$TF_SSM_PROXY_AMI_ID" ]]; then
  echo "TF_SSM_PROXY_AMI_ID is required" >&2
  exit 64
fi
case "$TARGET_ENV" in
  dev)
    project_name="delivery-platform-dev"
    vpc_cidr="10.20.0.0/16"
    public_subnets='["10.20.1.0/24", "10.20.2.0/24"]'
    private_subnets='["10.20.11.0/24", "10.20.12.0/24"]'
    enable_web_ssm="true"
    web_min_size=1
    web_desired_capacity=1
    web_max_size=2
    asg_min_healthy_percentage=50
    asg_instance_warmup_seconds=120
    asg_checkpoint_delay_seconds=180
    tg_slow_start_seconds=60
    health_check_healthy_threshold=2
    enable_alb_deletion_protection=false
    criticality="low"
    ;;
  stage)
    project_name="delivery-platform-stage"
    vpc_cidr="10.30.0.0/16"
    public_subnets='["10.30.1.0/24", "10.30.2.0/24"]'
    private_subnets='["10.30.11.0/24", "10.30.12.0/24"]'
    enable_web_ssm="true"
    web_min_size=2
    web_desired_capacity=2
    web_max_size=3
    asg_min_healthy_percentage=50
    asg_instance_warmup_seconds=120
    asg_checkpoint_delay_seconds=360
    tg_slow_start_seconds=60
    health_check_healthy_threshold=2
    enable_alb_deletion_protection=false
    criticality="medium"
    ;;
  prod)
    project_name="delivery-platform-prod"
    vpc_cidr="10.40.0.0/16"
    public_subnets='["10.40.1.0/24", "10.40.2.0/24"]'
    private_subnets='["10.40.11.0/24", "10.40.12.0/24"]'
    enable_web_ssm="false"
    web_min_size=2
    web_desired_capacity=2
    web_max_size=4
    asg_min_healthy_percentage=100
    asg_instance_warmup_seconds=180
    asg_checkpoint_delay_seconds=600
    tg_slow_start_seconds=120
    health_check_healthy_threshold=3
    enable_alb_deletion_protection=true
    prod_teardown_mode_line="prod_teardown_mode             = false"
    criticality="high"
    ;;
esac

mkdir -p "$ENV_DIR"

cat > "${ENV_DIR}/backend.hcl" <<BACKEND
bucket       = "${TF_STATE_BUCKET}"
key          = "delivery-platform/${TARGET_ENV}/full/terraform.tfstate"
region       = "${AWS_REGION}"
encrypt      = true
use_lockfile = true
BACKEND

cat > "${ENV_DIR}/terraform.auto.tfvars" <<TFVARS
aws_region   = "${AWS_REGION}"
project_name = "${project_name}"
environment  = "${TARGET_ENV}"

vpc_cidr             = "${vpc_cidr}"
public_subnet_cidrs  = ${public_subnets}
private_subnet_cidrs = ${private_subnets}

enable_web_ssm = ${enable_web_ssm}

web_ami_id       = "${TF_WEB_AMI_ID}"
ssm_proxy_ami_id = "${TF_SSM_PROXY_AMI_ID}"

web_min_size         = ${web_min_size}
web_desired_capacity = ${web_desired_capacity}
web_max_size         = ${web_max_size}

asg_min_healthy_percentage     = ${asg_min_healthy_percentage}
asg_instance_warmup_seconds    = ${asg_instance_warmup_seconds}
asg_checkpoint_delay_seconds   = ${asg_checkpoint_delay_seconds}
tg_slow_start_seconds          = ${tg_slow_start_seconds}
health_check_healthy_threshold = ${health_check_healthy_threshold}
enable_alb_deletion_protection = ${enable_alb_deletion_protection}
${prod_teardown_mode_line}
instance_type_web              = "t3.micro"

tf_state_key = "delivery-platform/${TARGET_ENV}/full/terraform.tfstate"

demo_api_token_parameter_name = "/devops/delivery-platform/${TARGET_ENV}/demo/api-token"
demo_app_secret_name          = "/devops/delivery-platform/${TARGET_ENV}/demo/app-secret"

common_tags = {
  Owner       = "PlatformTeam"
  Criticality = "${criticality}"
}
TFVARS

echo "Wrote ${ENV_DIR}/backend.hcl"
echo "Wrote ${ENV_DIR}/terraform.auto.tfvars"
