#!/bin/bash
# -------------------------------------------------------
# push-images.sh — Build & push Docker images to ECR
# Builds both service images locally and pushes them to
# their respective ECR repositories.
# Usage: ./scripts/push-images.sh [--tag <TAG>]
#   Default tag: git short SHA or "latest"
# -------------------------------------------------------

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ==================== Parse arguments ====================
IMAGE_TAG="latest"
if [[ "${1:-}" == "--tag" && -n "${2:-}" ]]; then
  IMAGE_TAG="$2"
elif command -v git &> /dev/null && git rev-parse --short HEAD &> /dev/null; then
  IMAGE_TAG="$(git rev-parse --short HEAD)"
fi

# ==================== Configuration ====================
# These should match your terraform.tfvars or defaults
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
ECR_REPO_A="${ECR_REPO_A:-service-a}"
ECR_REPO_B="${ECR_REPO_B:-service-b}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Multi-Cloud DevOps — Push Images${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  Region:     $AWS_REGION"
echo "  Tag:        $IMAGE_TAG"
echo "  Service A:  $ECR_REPO_A"
echo "  Service B:  $ECR_REPO_B"
echo ""

# ==================== Pre-flight checks ====================
echo -e "${YELLOW}[1/5] Running pre-flight checks...${NC}"

if ! command -v docker &> /dev/null; then
  echo -e "${RED}ERROR: Docker not found.${NC}"
  exit 1
fi

if ! command -v aws &> /dev/null; then
  echo -e "${RED}ERROR: AWS CLI not found.${NC}"
  exit 1
fi

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
  echo -e "${YELLOW}  AWS_ACCOUNT_ID not set — fetching from STS...${NC}"
  AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
fi

ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
echo -e "${GREEN}  ✓ ECR URI: $ECR_URI${NC}"
echo ""

# ==================== ECR Login ====================
echo -e "${YELLOW}[2/5] Authenticating with ECR...${NC}"
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_URI"
echo ""

# ==================== Build Service A ====================
echo -e "${YELLOW}[3/5] Building Service A...${NC}"
docker build \
  -t "$ECR_URI/$ECR_REPO_A:$IMAGE_TAG" \
  -t "$ECR_URI/$ECR_REPO_A:latest" \
  "$PROJECT_ROOT/services/service-a"
echo ""

# ==================== Build Service B ====================
echo -e "${YELLOW}[4/5] Building Service B...${NC}"
docker build \
  -t "$ECR_URI/$ECR_REPO_B:$IMAGE_TAG" \
  -t "$ECR_URI/$ECR_REPO_B:latest" \
  "$PROJECT_ROOT/services/service-b"
echo ""

# ==================== Push Images ====================
echo -e "${YELLOW}[5/5] Pushing images to ECR...${NC}"

echo "  Pushing $ECR_REPO_A:$IMAGE_TAG..."
docker push "$ECR_URI/$ECR_REPO_A:$IMAGE_TAG"
docker push "$ECR_URI/$ECR_REPO_A:latest"

echo "  Pushing $ECR_REPO_B:$IMAGE_TAG..."
docker push "$ECR_URI/$ECR_REPO_B:$IMAGE_TAG"
docker push "$ECR_URI/$ECR_REPO_B:latest"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Images pushed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  $ECR_URI/$ECR_REPO_A:$IMAGE_TAG"
echo "  $ECR_URI/$ECR_REPO_B:$IMAGE_TAG"
