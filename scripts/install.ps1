# data-layer/scripts/install.ps1 — Windows installer for the data-layer stack.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/install.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -DryRun
#   powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -SkipBuild
#
# This script:
#   1. Checks for Docker Desktop
#   2. Initializes git submodules
#   3. Generates secure random passwords
#   4. Materializes .env from .env.example
#   5. Builds and starts all services via docker compose
#   6. Prints next steps for running migrations (requires bash/WSL)

param(
    [switch]$DryRun,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

function Write-Step($msg) { Write-Host "[install] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[install OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[install WARN] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "[install FAIL] $msg" -ForegroundColor Red; exit 1 }

# ── Step 1: Check Docker ─────────────────────────────────────────────
Write-Step "Step 1/6 — checking Docker Desktop"
try {
    $dockerVer = docker --version 2>&1
    Write-Host "  $dockerVer"
} catch {
    Write-Fail "Docker is not installed. Install Docker Desktop from https://docker.com/products/docker-desktop"
}

try {
    $composeVer = docker compose version 2>&1
    Write-Host "  $composeVer"
} catch {
    Write-Fail "Docker Compose plugin not found. Update Docker Desktop."
}

try {
    docker info 2>&1 | Out-Null
    Write-Ok "Docker daemon running"
} catch {
    Write-Fail "Docker daemon is not running. Start Docker Desktop and retry."
}

# ── Step 2: Git submodules ───────────────────────────────────────────
Write-Step "Step 2/6 — initializing git submodules"
if (Test-Path "$RootDir\.gitmodules") {
    if ($DryRun) {
        Write-Host "  [dry-run] would run: git submodule update --init --recursive"
    } else {
        Push-Location $RootDir
        git submodule update --init --recursive
        Pop-Location
        Write-Ok "submodules populated"
    }
} else {
    Write-Warn "no .gitmodules found; skipping"
}

# ── Step 3: Generate secrets ─────────────────────────────────────────
Write-Step "Step 3/6 — generating secrets"

function New-SafePassword {
    param([int]$Length = 32)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] $Length
    $rng.GetBytes($bytes)
    $result = ''
    for ($i = 0; $i -lt $Length; $i++) {
        $result += $chars[$bytes[$i] % $chars.Length]
    }
    return $result
}

$EnvFile = Join-Path $RootDir ".env"
$EnvExample = Join-Path $RootDir ".env.example"

$postgresPw = ""
$agentZeroPw = ""

# Read existing .env if present
if (Test-Path $EnvFile) {
    Write-Host "  .env already exists; preserving existing passwords"
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^(?:POSTGRES_PASSWORD)=(.+)$') { $postgresPw = $Matches[1] }
        if ($_ -match '^(?:DATA_LAYER_AGENT_ZERO_PASSWORD)=(.+)$') { $agentZeroPw = $Matches[1] }
    }
}

if (-not $postgresPw)  { $postgresPw = New-SafePassword; Write-Host "  generated POSTGRES_PASSWORD" }
if (-not $agentZeroPw) { $agentZeroPw = New-SafePassword; Write-Host "  generated DATA_LAYER_AGENT_ZERO_PASSWORD" }

if ($DryRun) {
    Write-Host "  [dry-run] would write .env"
} else {
    if (Test-Path $EnvExample) {
        $foundPg = $false
        $foundAz = $false
        $lines = @()
        Get-Content $EnvExample | ForEach-Object {
            if ($_ -match '^POSTGRES_PASSWORD=') {
                $lines += "POSTGRES_PASSWORD=$postgresPw"
                $foundPg = $true
            } elseif ($_ -match '^DATA_LAYER_AGENT_ZERO_PASSWORD=') {
                $lines += "DATA_LAYER_AGENT_ZERO_PASSWORD=$agentZeroPw"
                $foundAz = $true
            } else {
                $lines += $_
            }
        }
        if (-not $foundPg) { $lines += "POSTGRES_PASSWORD=$postgresPw" }
        if (-not $foundAz) { $lines += "DATA_LAYER_AGENT_ZERO_PASSWORD=$agentZeroPw" }
        $lines | Set-Content -Path $EnvFile
        Write-Ok ".env materialized"
    } else {
        @"
POSTGRES_PASSWORD=$postgresPw
DATA_LAYER_AGENT_ZERO_PASSWORD=$agentZeroPw
DATA_LAYER_BASE=$RootDir
"@ | Set-Content -Path $EnvFile
        Write-Ok ".env created (minimal)"
    }
}

# ── Step 4: Docker compose up ────────────────────────────────────────
Write-Step "Step 4/6 — docker compose"
if ($SkipBuild) {
    if ($DryRun) {
        Write-Host "  [dry-run] would run: docker compose up -d"
    } else {
        Push-Location $RootDir
        docker compose up -d
        Pop-Location
        Write-Ok "containers started"
    }
} else {
    if ($DryRun) {
        Write-Host "  [dry-run] would run: docker compose up -d --build"
    } else {
        Push-Location $RootDir
        docker compose up -d --build
        Pop-Location
        Write-Ok "containers built and started"
    }
}

# ── Step 5: Wait for healthchecks ────────────────────────────────────
Write-Step "Step 5/6 — waiting for healthchecks (up to 90s)"
if (-not $DryRun) {
    $elapsed = 0
    $maxWait = 90
    while ($elapsed -lt $maxWait) {
        Start-Sleep -Seconds 5
        $elapsed += 5
        $psOutput = Push-Location $RootDir; docker compose ps 2>&1; Pop-Location
        $healthyCount = ($psOutput | Select-String -Pattern 'healthy').Count
        Write-Host "  waiting... (${elapsed}s, $healthyCount healthy)"
        if ($healthyCount -ge 3) {
            Write-Ok "services healthy ($healthyCount/4)"
            break
        }
    }
    if ($elapsed -ge $maxWait) {
        Write-Warn "healthcheck timeout — services may still be starting"
    }
}

# ── Step 6: Summary ──────────────────────────────────────────────────
Write-Step "Step 6/6 — done"
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  data-layer stack — containers running" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Services:"
Write-Host "    postgres   →  localhost:5432  (user: postgres)"
Write-Host "    redis      →  localhost:6380"
Write-Host "    falkordb   →  localhost:6379 (RESP) / 7687 (Bolt) / 3000 (UI)"
Write-Host ""
Write-Host "  Credentials (saved in .env):"
Write-Host "    POSTGRES_PASSWORD              = $postgresPw"
Write-Host "    DATA_LAYER_AGENT_ZERO_PASSWORD = $agentZeroPw"
Write-Host ""
Write-Host "  Next steps (requires bash — use WSL or Git Bash):"
Write-Host "    bash bootstrap all       # apply migrations + seeds"
Write-Host "    bash bootstrap verify    # confirm all services are reachable"
Write-Host ""
Write-Host "  Stop:    docker compose down"
Write-Host "  Reset:   docker compose down -v  (DROPS ALL DATA)"
Write-Host "============================================================" -ForegroundColor Cyan
