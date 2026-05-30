# -------------------------------------------------------
# push-images.ps1 — Build & push Docker images to ECR
# Builds both service images and pushes to ECR.
# Usage: .\scripts\push-images.ps1 [-Tag "v1.0.0"]
#   Default tag: git short SHA or "latest"
# -------------------------------------------------------

param(
    [string]$Tag = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# ==================== Determine image tag ====================
if (-not $Tag) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $Tag = git rev-parse --short HEAD 2>$null
    }
    if (-not $Tag) { $Tag = "latest" }
}

# ==================== Configuration ====================
$AwsRegion = if ($env:AWS_REGION) { $env:AWS_REGION } else { "ap-southeast-2" }
$AwsAccountId = if ($env:AWS_ACCOUNT_ID) { $env:AWS_ACCOUNT_ID } else { "" }
$EcrRepoA = if ($env:ECR_REPO_A) { $env:ECR_REPO_A } else { "multicloud-devops-dev-service-a" }
$EcrRepoB = if ($env:ECR_REPO_B) { $env:ECR_REPO_B } else { "multicloud-devops-dev-service-b" }

Write-Host "========================================" -ForegroundColor Green
Write-Host " Multi-Cloud DevOps - Push Images" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Region:     $AwsRegion"
Write-Host "  Tag:        $Tag"
Write-Host "  Service A:  $EcrRepoA"
Write-Host "  Service B:  $EcrRepoB"
Write-Host ""

# ==================== Pre-flight checks ====================
Write-Host "[1/5] Running pre-flight checks..." -ForegroundColor Yellow

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Docker not found." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: AWS CLI not found." -ForegroundColor Red
    exit 1
}

if (-not $AwsAccountId) {
    Write-Host "  AWS_ACCOUNT_ID not set - fetching from STS..." -ForegroundColor Yellow
    $AwsAccountId = aws sts get-caller-identity --query Account --output text
}

$EcrUri = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
Write-Host "  + ECR URI: $EcrUri" -ForegroundColor Green
Write-Host ""

# ==================== ECR Login ====================
Write-Host "[2/5] Authenticating with ECR..." -ForegroundColor Yellow
$password = aws ecr get-login-password --region $AwsRegion
$password | docker login --username AWS --password-stdin $EcrUri
if ($LASTEXITCODE -ne 0) { throw "ECR login failed" }
Write-Host ""

# ==================== Build Service A ====================
Write-Host "[3/5] Building Service A..." -ForegroundColor Yellow
docker build `
    -t "$EcrUri/${EcrRepoA}:$Tag" `
    -t "$EcrUri/${EcrRepoA}:latest" `
    "$ProjectRoot\services\service-a"
if ($LASTEXITCODE -ne 0) { throw "Service A build failed" }
Write-Host ""

# ==================== Build Service B ====================
Write-Host "[4/5] Building Service B..." -ForegroundColor Yellow
docker build `
    -t "$EcrUri/${EcrRepoB}:$Tag" `
    -t "$EcrUri/${EcrRepoB}:latest" `
    "$ProjectRoot\services\service-b"
if ($LASTEXITCODE -ne 0) { throw "Service B build failed" }
Write-Host ""

# ==================== Push Images ====================
Write-Host "[5/5] Pushing images to ECR..." -ForegroundColor Yellow

Write-Host "  Pushing ${EcrRepoA}:$Tag..."
docker push "$EcrUri/${EcrRepoA}:$Tag"
docker push "$EcrUri/${EcrRepoA}:latest"

Write-Host "  Pushing ${EcrRepoB}:$Tag..."
docker push "$EcrUri/${EcrRepoB}:$Tag"
docker push "$EcrUri/${EcrRepoB}:latest"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Images pushed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  $EcrUri/${EcrRepoA}:$Tag"
Write-Host "  $EcrUri/${EcrRepoB}:$Tag"
