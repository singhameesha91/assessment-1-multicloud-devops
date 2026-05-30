#!/bin/bash
# -------------------------------------------------------
# destroy.sh — Tear down all infrastructure
# Destroys all Terraform-managed resources safely.
# Usage: ./scripts/destroy.sh [--auto-approve]
#
# WARNING: This permanently deletes all cloud resources.
# The S3 state bucket and DynamoDB lock table (backend)
# are NOT destroyed — they must be removed manually if needed.
# -------------------------------------------------------

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

AUTO_APPROVE=""
if [[ "${1:-}" == "--auto-approve" ]]; then
  AUTO_APPROVE="-auto-approve"
fi

echo -e "${RED}========================================${NC}"
echo -e "${RED} Multi-Cloud DevOps — DESTROY${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${RED}⚠ This will PERMANENTLY delete all cloud resources!${NC}"
echo ""

# ==================== Pre-flight checks ====================
echo -e "${YELLOW}[1/3] Running pre-flight checks...${NC}"

if ! command -v terraform &> /dev/null; then
  echo -e "${RED}ERROR: terraform CLI not found.${NC}"
  exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${RED}ERROR: AWS credentials not configured.${NC}"
  exit 1
fi

echo -e "${GREEN}  ✓ Pre-flight checks passed${NC}"
echo ""

# ==================== Confirmation ====================
if [[ -z "$AUTO_APPROVE" ]]; then
  echo -e "${RED}Type 'destroy' to confirm teardown:${NC}"
  read -rp "> " confirm
  if [[ "$confirm" != "destroy" ]]; then
    echo -e "${YELLOW}Aborted. No resources were deleted.${NC}"
    exit 0
  fi
fi

# ==================== Terraform Destroy ====================
echo -e "${YELLOW}[2/3] Planning destruction...${NC}"
cd "$TERRAFORM_DIR"
terraform init -upgrade
echo ""

echo -e "${YELLOW}[3/3] Destroying infrastructure...${NC}"
if [[ -n "$AUTO_APPROVE" ]]; then
  terraform destroy -auto-approve
else
  terraform destroy
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} All resources destroyed.${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Note: The following remain and must be removed manually if needed:${NC}"
echo "  - S3 state bucket (terraform backend)"
echo "  - DynamoDB state lock table (terraform backend)"
echo "  - CodeStar GitHub connection (created via console)"
echo "  - Azure Entra ID Enterprise Application (created via portal)"
