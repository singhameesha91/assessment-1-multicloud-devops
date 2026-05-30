# -------------------------------------------------------
# deploy.ps1 — Full infrastructure deployment
# Runs terraform init → plan → apply for the project.
# Usage: .\scripts\deploy.ps1 [-AutoApprove]
# -------------------------------------------------------

param(
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $ProjectRoot "terraform"

Write-Host "========================================" -ForegroundColor Green
Write-Host " Multi-Cloud DevOps - Deploy" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# ==================== Pre-flight checks ====================
Write-Host "[1/5] Running pre-flight checks..." -ForegroundColor Yellow

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: terraform CLI not found. Install from https://developer.hashicorp.com/terraform/install" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: AWS CLI not found. Install from https://aws.amazon.com/cli/" -ForegroundColor Red
    exit 1
}

# Verify AWS credentials
try {
    aws sts get-caller-identity | Out-Null
} catch {
    Write-Host "ERROR: AWS credentials not configured. Run 'aws configure' first." -ForegroundColor Red
    exit 1
}

$tfVersion = terraform version -json | ConvertFrom-Json
Write-Host "  + terraform found (v$($tfVersion.terraform_version))" -ForegroundColor Green
Write-Host "  + AWS CLI configured" -ForegroundColor Green
Write-Host ""

# ==================== Terraform Init ====================
Write-Host "[2/5] Initialising Terraform..." -ForegroundColor Yellow
Push-Location $TerraformDir
try {
    terraform init -upgrade
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed" }
    Write-Host ""

    # ==================== Terraform Validate ====================
    Write-Host "[3/5] Validating configuration..." -ForegroundColor Yellow
    terraform validate
    if ($LASTEXITCODE -ne 0) { throw "terraform validate failed" }
    Write-Host ""

    # ==================== Terraform Plan ====================
    Write-Host "[4/5] Planning infrastructure changes..." -ForegroundColor Yellow
    terraform plan -out=tfplan
    if ($LASTEXITCODE -ne 0) { throw "terraform plan failed" }
    Write-Host ""

    # ==================== Terraform Apply ====================
    Write-Host "[5/5] Applying infrastructure..." -ForegroundColor Yellow
    if ($AutoApprove) {
        terraform apply -auto-approve tfplan
    } else {
        $confirm = Read-Host "Review the plan above. Continue? [y/N]"
        if ($confirm -match "^[Yy]$") {
            terraform apply tfplan
        } else {
            Write-Host "Aborted." -ForegroundColor Red
            Remove-Item -Force tfplan -ErrorAction SilentlyContinue
            exit 1
        }
    }

    if ($LASTEXITCODE -ne 0) { throw "terraform apply failed" }
    Remove-Item -Force tfplan -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " Deployment complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Useful outputs:"
    terraform output
} finally {
    Pop-Location
}
