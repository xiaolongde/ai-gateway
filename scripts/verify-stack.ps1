# scripts/verify-stack.ps1
# Full M1.5-1 verification. Run after Docker Desktop installed.
#
# What it does:
#   1. Confirm Docker Desktop is running
#   2. docker compose build copilot-api (1st time only — cached after)
#   3. docker compose up -d (postgres, litellm, copilot-api, costpage)
#   4. Wait up to 3 min for litellm healthy AND Win 127.0.0.1:4000/health/readiness
#      to return 200 for N=5 consecutive checks (no flaky declarations)
#   5. Run node tests/smoke-test.js (10 cases: 6 core + stage 4 admin UI + stage 5 cost.html)
#   6. Print UI_PASSWORD from .env so user can log in to /ui

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Bypass Clash for localhost
$env:NO_PROXY = '127.0.0.1,localhost,::1'

function Title([string]$s) { Write-Host "`n=== $s ===" -ForegroundColor Cyan }
function OK([string]$s)    { Write-Host "  [OK] $s" -ForegroundColor Green }
function FAIL([string]$s)  { Write-Host "  [FAIL] $s" -ForegroundColor Red }

# ---- 1. Docker Desktop running? ----
Title "1. Docker Desktop"
try {
    $info = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { FAIL "docker info failed: $info"; exit 1 }
    $serverVer = ($info | Select-String 'Server Version:' | Select-Object -First 1).Line.Trim()
    OK "docker reachable; $serverVer"
} catch {
    FAIL "docker CLI not found. Install Docker Desktop and ensure it is started."
    exit 1
}

# ---- 2. build copilot-api ----
Title "2. compose build copilot-api"
docker compose build copilot-api 2>&1 | Select-Object -Last 5
if ($LASTEXITCODE -ne 0) { FAIL "build failed"; exit 1 }
OK "image built (or cached)"

# ---- 3. up ----
Title "3. compose up -d"
docker compose up -d 2>&1 | Select-Object -Last 8
if ($LASTEXITCODE -ne 0) { FAIL "up failed"; exit 1 }

# ---- 4. wait healthy + Win-reachable, N=5 consecutive 200 ----
Title "4. Wait for litellm healthy + Win reachable (N=5 consecutive 200)"
$deadline = (Get-Date).AddMinutes(3)
$consecutive = 0
$reached = $false
while ((Get-Date) -lt $deadline) {
    try {
        $resp = Invoke-WebRequest -Uri 'http://127.0.0.1:4000/health/readiness' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $consecutive++
            Write-Host ("  [{0}] 200 OK (consecutive {1}/5)" -f (Get-Date -Format 'HH:mm:ss'), $consecutive)
            if ($consecutive -ge 5) { $reached = $true; break }
        } else {
            Write-Host ("  [{0}] {1} — reset" -f (Get-Date -Format 'HH:mm:ss'), $resp.StatusCode)
            $consecutive = 0
        }
    } catch {
        Write-Host ("  [{0}] unreachable — reset" -f (Get-Date -Format 'HH:mm:ss'))
        $consecutive = 0
    }
    Start-Sleep -Seconds 6
}
if (-not $reached) {
    FAIL "litellm did not stabilize at 200 in 3 min. Logs:"
    docker compose logs litellm --tail 25
    exit 1
}
OK "stable at 200"

# ---- 5. smoke ----
Title "5. node tests/smoke-test.js"
node tests/smoke-test.js
$smokeExit = $LASTEXITCODE
if ($smokeExit -eq 0) { OK "smoke PASS" } else { FAIL "smoke FAIL (exit=$smokeExit)" }

# ---- 6. credentials for /ui ----
Title "6. Admin UI credentials"
$ui_user = (Get-Content .env | Select-String '^UI_USERNAME=' | ForEach-Object { ($_ -split '=', 2)[1] }) -join ''
$ui_pass = (Get-Content .env | Select-String '^UI_PASSWORD=' | ForEach-Object { ($_ -split '=', 2)[1] }) -join ''
Write-Host "  URL:      http://127.0.0.1:4000/ui"
Write-Host "  Username: $ui_user"
Write-Host "  Password: $ui_pass"

Write-Host ""
if ($reached -and $smokeExit -eq 0) {
    Write-Host "M1.5-1 VERIFIED OK." -ForegroundColor Green
    exit 0
} else {
    Write-Host "M1.5-1 VERIFY FAILED." -ForegroundColor Red
    exit 1
}
