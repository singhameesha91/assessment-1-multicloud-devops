# -------------------------------------------------------
# validate.ps1 — Validate Terraform configuration
# Runs format check, validation, and Docker Compose check.
# Usage: .\scripts\validate.ps1
# -------------------------------------------------------

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $ProjectRoot "terraform"

$Errors = 0

Write-Host "========================================" -ForegroundColor Green
Write-Host " Multi-Cloud DevOps - Validate" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Push-Location $TerraformDir
try {
    # ==================== Terraform Format Check ====================
    Write-Host "[1/4] Checking formatting (terraform fmt)..." -ForegroundColor Yellow
    terraform fmt -check -recursive -diff
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  + All files correctly formatted" -ForegroundColor Green
    } else {
        Write-Host "  x Formatting issues found. Run 'terraform fmt -recursive' to fix." -ForegroundColor Red
        $Errors++
    }
    Write-Host ""

    # ==================== Terraform Init ====================
    Write-Host "[2/4] Initialising (terraform init)..." -ForegroundColor Yellow
    terraform init -backend=false 2>&1 | Out-Null
    Write-Host "  + Init successful" -ForegroundColor Green
    Write-Host ""

    # ==================== Terraform Validate ====================
    Write-Host "[3/4] Validating configuration (terraform validate)..." -ForegroundColor Yellow
    terraform validate
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  + Configuration is valid" -ForegroundColor Green
    } else {
        Write-Host "  x Validation failed" -ForegroundColor Red
        $Errors++
    }
    Write-Host ""

    # ==================== Docker Compose Validation ====================
    Write-Host "[4/4] Validating Docker Compose..." -ForegroundColor Yellow
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Push-Location $ProjectRoot
        try {
            docker compose config --quiet 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  + docker-compose.yml is valid" -ForegroundColor Green
            } else {
                Write-Host "  x docker-compose.yml has errors" -ForegroundColor Red
                $Errors++
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "  ~ Docker not found - skipping compose validation" -ForegroundColor Yellow
    }
    Write-Host ""

    # ==================== Summary ====================
    Write-Host "========================================" -ForegroundColor Green
    if ($Errors -eq 0) {
        Write-Host " All checks passed!" -ForegroundColor Green
    } else {
        Write-Host " $Errors check(s) failed" -ForegroundColor Red
    }
    Write-Host "========================================" -ForegroundColor Green
} finally {
    Pop-Location
}

exit $Errors
