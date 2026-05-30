# -------------------------------------------------------
# destroy.ps1 — Tear down all infrastructure
# Destroys all Terraform-managed resources safely.
# Usage: .\scripts\destroy.ps1 [-AutoApprove]
#
# WARNING: This permanently deletes all cloud resources.
# -------------------------------------------------------

param(
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $ProjectRoot "terraform"

Write-Host "========================================" -ForegroundColor Red
Write-Host " Multi-Cloud DevOps - DESTROY" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "WARNING: This will PERMANENTLY delete all cloud resources!" -ForegroundColor Red
Write-Host ""

# ==================== Pre-flight checks ====================
Write-Host "[1/3] Running pre-flight checks..." -ForegroundColor Yellow

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: terraform CLI not found." -ForegroundColor Red
    exit 1
}

try {
    aws sts get-caller-identity | Out-Null
} catch {
    Write-Host "ERROR: AWS credentials not configured." -ForegroundColor Red
    exit 1
}

Write-Host "  + Pre-flight checks passed" -ForegroundColor Green
Write-Host ""

# ==================== Confirmation ====================
if (-not $AutoApprove) {
    $confirm = Read-Host "Type 'destroy' to confirm teardown"
    if ($confirm -ne "destroy") {
        Write-Host "Aborted. No resources were deleted." -ForegroundColor Yellow
        exit 0
    }
}

# ==================== Terraform Destroy ====================
Push-Location $TerraformDir
try {
    Write-Host "[2/3] Initialising Terraform..." -ForegroundColor Yellow
    terraform init -upgrade
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed" }
    Write-Host ""

    Write-Host "[3/3] Destroying infrastructure..." -ForegroundColor Yellow
    if ($AutoApprove) {
        terraform destroy -auto-approve
    } else {
        terraform destroy
    }

    if ($LASTEXITCODE -ne 0) { throw "terraform destroy failed" }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " All resources destroyed." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: The following remain and must be removed manually if needed:" -ForegroundColor Yellow
    Write-Host "  - S3 state bucket (terraform backend)"
    Write-Host "  - DynamoDB state lock table (terraform backend)"
    Write-Host "  - CodeStar GitHub connection (created via console)"
    Write-Host "  - Azure Entra ID Enterprise Application (created via portal)"
} finally {
    Pop-Location
}
