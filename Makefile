SHELL := /usr/bin/env bash
PROJECT_DIR := $(CURDIR)
TERRAFORM_DIR := terraform
PACKER_DIR := packer
TFLINT_CONFIG := $(PROJECT_DIR)/terraform/.tflint.hcl
TFLINT_PLUGIN_DIR ?= /tmp/delivery-platform-tflint-plugin-cache

.PHONY: help check check-full fmt terraform-fmt packer-fmt shellcheck policy-test opa-test terraform-test validate tflint checkov yaml redaction-smoke clean-local

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make check           Fast local checks, no AWS credentials required' \
	  '  make check-full      Fast checks plus Terraform init/test/validate' \
	  '  make fmt             Terraform and Packer format checks' \
	  '  make tflint          TFLint over Terraform roots' \
	  '  make checkov         Checkov Terraform scan' \
	  '  make yaml            Parse GitHub workflow YAML' \
	  '  make redaction-smoke Test evidence redaction helper' \
	  '  make clean-local     Remove local tool caches created by this Makefile'

check:
	./scripts/run-local-checks.sh

check-full:
	RUN_TERRAFORM=true ./scripts/run-local-checks.sh

fmt: terraform-fmt packer-fmt

terraform-fmt:
	terraform fmt -check -recursive $(TERRAFORM_DIR)

packer-fmt:
	packer fmt -check -recursive $(PACKER_DIR)

shellcheck:
	find . -type f -name '*.sh' -print0 | xargs -0 -r shellcheck

policy-test:
	./policies/test-security-policy.sh
	./policies/test-cost-policy.sh
	./policies/test-risk-classifier.sh

opa-test:
	./policies/test-opa.sh

terraform-test:
	TF_DATA_DIR=/tmp/delivery-platform-module-test-data terraform -chdir=terraform/modules/network init -backend=false -input=false -no-color
	TF_DATA_DIR=/tmp/delivery-platform-module-test-data terraform -chdir=terraform/modules/network test -no-color

validate:
	@for env_name in dev stage prod; do \
	  echo "==> terraform validate $$env_name"; \
	  TF_DATA_DIR="/tmp/delivery-platform-$$env_name-data" terraform -chdir="terraform/envs/$$env_name" init -backend=false -input=false -no-color; \
	  TF_DATA_DIR="/tmp/delivery-platform-$$env_name-data" terraform -chdir="terraform/envs/$$env_name" validate -no-color; \
	done

tflint:
	TFLINT_PLUGIN_DIR='$(TFLINT_PLUGIN_DIR)' tflint --config '$(TFLINT_CONFIG)' --init
	@for root in terraform/backend-bootstrap terraform/audit-trail terraform/envs/dev terraform/envs/stage terraform/envs/prod terraform/modules/network; do \
	  echo "==> tflint $$root"; \
	  TFLINT_PLUGIN_DIR='$(TFLINT_PLUGIN_DIR)' tflint --config '$(TFLINT_CONFIG)' --chdir "$$root" -f compact; \
	done

checkov:
	checkov -d $(TERRAFORM_DIR) --framework terraform --config-file checkov.yaml --skip-download

yaml:
	python3 -c "from pathlib import Path; import yaml; [print(f'OK {p}') for p in sorted(Path('.github/workflows').glob('*.yml')) if yaml.safe_load(p.open()) is not None]"

redaction-smoke:
	@tmp_in="$$(mktemp)"; tmp_out="$$(mktemp)"; \
	printf '%s\n' \
	  'arn:aws:iam::123456789012:role/delivery-platform-prod-github-actions-apply-role' \
	  'Instance i-0123456789abcdef0 from 10.20.11.42 reached internal-demo.eu-west-1.elb.amazonaws.com' \
	  > "$$tmp_in"; \
	./scripts/redact-evidence.sh "$$tmp_in" "$$tmp_out" >/dev/null; \
	! grep -q '123456789012\|i-0123456789abcdef0\|10.20.11.42' "$$tmp_out"; \
	rm -f "$$tmp_in" "$$tmp_out"; \
	echo 'redaction smoke passed'

clean-local:
	rm -rf /tmp/delivery-platform-*-data /tmp/delivery-platform-module-test-data '$(TFLINT_PLUGIN_DIR)'
