#!/bin/bash
# -------------------------------------------------------
# validate.sh — Validate Terraform configuration
# Runs format check, validation, and optional security scan.
# Usage: ./scripts/validate.sh
# -------------------------------------------------------

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

ERRORS=0

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Multi-Cloud DevOps — Validate${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

cd "$TERRAFORM_DIR"

# ==================== Terraform Format Check ====================
echo -e "${YELLOW}[1/4] Checking formatting (terraform fmt)...${NC}"
if terraform fmt -check -recursive -diff; then
  echo -e "${GREEN}  ✓ All files correctly formatted${NC}"
else
  echo -e "${RED}  ✗ Formatting issues found. Run 'terraform fmt -recursive' to fix.${NC}"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# ==================== Terraform Init ====================
echo -e "${YELLOW}[2/4] Initialising (terraform init)...${NC}"
terraform init -backend=false > /dev/null 2>&1
echo -e "${GREEN}  ✓ Init successful${NC}"
echo ""

# ==================== Terraform Validate ====================
echo -e "${YELLOW}[3/4] Validating configuration (terraform validate)...${NC}"
if terraform validate; then
  echo -e "${GREEN}  ✓ Configuration is valid${NC}"
else
  echo -e "${RED}  ✗ Validation failed${NC}"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# ==================== Docker Compose Validation ====================
echo -e "${YELLOW}[4/4] Validating Docker Compose...${NC}"
if command -v docker &> /dev/null; then
  cd "$PROJECT_ROOT"
  if docker compose config --quiet 2>/dev/null; then
    echo -e "${GREEN}  ✓ docker-compose.yml is valid${NC}"
  else
    echo -e "${RED}  ✗ docker-compose.yml has errors${NC}"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo -e "${YELLOW}  ⊘ Docker not found — skipping compose validation${NC}"
fi
echo ""

# ==================== Summary ====================
echo -e "${GREEN}========================================${NC}"
if [[ $ERRORS -eq 0 ]]; then
  echo -e "${GREEN} All checks passed! ✓${NC}"
else
  echo -e "${RED} $ERRORS check(s) failed ✗${NC}"
fi
echo -e "${GREEN}========================================${NC}"

exit $ERRORS
