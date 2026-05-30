#!/bin/bash
# -------------------------------------------------------
# deploy.sh — Full infrastructure deployment
# Runs terraform init → plan → apply for the project.
# Usage: ./scripts/deploy.sh [--auto-approve]
# -------------------------------------------------------

set -euo pipefail

# Colour output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

AUTO_APPROVE=""
if [[ "${1:-}" == "--auto-approve" ]]; then
  AUTO_APPROVE="-auto-approve"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Multi-Cloud DevOps — Deploy${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ==================== Pre-flight checks ====================
echo -e "${YELLOW}[1/5] Running pre-flight checks...${NC}"

if ! command -v terraform &> /dev/null; then
  echo -e "${RED}ERROR: terraform CLI not found. Install from https://developer.hashicorp.com/terraform/install${NC}"
  exit 1
fi

if ! command -v aws &> /dev/null; then
  echo -e "${RED}ERROR: AWS CLI not found. Install from https://aws.amazon.com/cli/${NC}"
  exit 1
fi

# Verify AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${RED}ERROR: AWS credentials not configured. Run 'aws configure' first.${NC}"
  exit 1
fi

echo -e "${GREEN}  ✓ terraform found ($(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4))${NC}"
echo -e "${GREEN}  ✓ AWS CLI configured${NC}"
echo ""

# ==================== Terraform Init ====================
echo -e "${YELLOW}[2/5] Initialising Terraform...${NC}"
cd "$TERRAFORM_DIR"
terraform init -upgrade
echo ""

# ==================== Terraform Validate ====================
echo -e "${YELLOW}[3/5] Validating configuration...${NC}"
terraform validate
echo ""

# ==================== Terraform Plan ====================
echo -e "${YELLOW}[4/5] Planning infrastructure changes...${NC}"
terraform plan -out=tfplan
echo ""

# ==================== Terraform Apply ====================
echo -e "${YELLOW}[5/5] Applying infrastructure...${NC}"
if [[ -n "$AUTO_APPROVE" ]]; then
  terraform apply $AUTO_APPROVE tfplan
else
  echo -e "${YELLOW}Review the plan above. Apply? (terraform apply tfplan)${NC}"
  read -rp "Continue? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    terraform apply tfplan
  else
    echo -e "${RED}Aborted.${NC}"
    rm -f tfplan
    exit 1
  fi
fi

rm -f tfplan

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Deployment complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Useful outputs:"
terraform output
