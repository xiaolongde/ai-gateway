# AI-Gateway: start LiteLLM + copilot-api together (idempotent).
# - Skips a service if its port already LISTENs (no kill).
# - Spawns each as a detached background process; logs in repo root.
# - Health checks both endpoints before returning.
# - Exit code: 0 = both healthy, 1 = at least one failed.
#
# Usage:
#   .\scripts\start-all.ps1                # default ports 4000 / 4141
#   .\scripts\start-all.ps1 -SkipHealthCheck

param(
    [int]$LiteLLMPort = 4000,
    [int]$CopilotPort = 4141,
    [string]$BindHost = "127.0.0.1",
    [int]$HealthTimeoutSec = 60,
    [switch]$SkipHealthCheck
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$logsDir = Join-Path $root "logs"
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

function Test-Port {
    param([int]$Port)
    $listening = netstat -ano | Select-String ":$Port\s+.*LISTENING"
    return [bool]$listening
}

function Wait-PortReady {
    param([int]$Port, [int]$TimeoutSec)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Port -Port $Port) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

# --- 1. copilot-api (:4141) ---
if (Test-Port -Port $CopilotPort) {
    Write-Host "[skip] copilot-api already LISTENING on :$CopilotPort" -ForegroundColor DarkGray
} else {
    Write-Host "[start] copilot-api on :$CopilotPort" -ForegroundColor Cyan
    $copilotLog = Join-Path $logsDir "copilot-api.log"
    $copilotErr = Join-Path $logsDir "copilot-api.err.log"
    # copilot-api is an npm global shim (.cmd); Start-Process cannot launch
    # .cmd directly, and `cmd /c` redirected to file loses async output.
    # Wrap in a child PowerShell that knows how to invoke .cmd shims.
    $copilotCmd = (Get-Command copilot-api -ErrorAction SilentlyContinue).Source
    if (-not $copilotCmd) { Write-Host "[fail] 'copilot-api' not found in PATH. Install: npm install -g copilot-api" -ForegroundColor Red; exit 1 }
    $inner = "`$env:NODE_USE_ENV_PROXY='1'; & `"$copilotCmd`" start --port $CopilotPort"
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile","-Command",$inner `
        -WindowStyle Hidden `
        -RedirectStandardOutput $copilotLog `
        -RedirectStandardError $copilotErr | Out-Null
    if (-not (Wait-PortReady -Port $CopilotPort -TimeoutSec $HealthTimeoutSec)) {
        Write-Host "[fail] copilot-api did not bind :$CopilotPort within ${HealthTimeoutSec}s. Check $copilotErr" -ForegroundColor Red
        exit 1
    }
    Write-Host "[ok] copilot-api listening on :$CopilotPort" -ForegroundColor Green
}

# --- 2. LiteLLM (:4000) ---
if (Test-Port -Port $LiteLLMPort) {
    Write-Host "[skip] LiteLLM already LISTENING on :$LiteLLMPort" -ForegroundColor DarkGray
} else {
    Write-Host "[start] LiteLLM on :$LiteLLMPort" -ForegroundColor Cyan
    $litellmLog = Join-Path $logsDir "litellm.log"
    $litellmErr = Join-Path $logsDir "litellm.err.log"
    $startScript = Join-Path $root "start.ps1"
    Start-Process -FilePath "powershell" `
        -ArgumentList "-NoProfile","-File",$startScript,"-Port",$LiteLLMPort,"-BindHost",$BindHost `
        -WorkingDirectory $root `
        -WindowStyle Hidden `
        -RedirectStandardOutput $litellmLog `
        -RedirectStandardError $litellmErr | Out-Null
    if (-not (Wait-PortReady -Port $LiteLLMPort -TimeoutSec $HealthTimeoutSec)) {
        Write-Host "[fail] LiteLLM did not bind :$LiteLLMPort within ${HealthTimeoutSec}s. Check $litellmErr" -ForegroundColor Red
        exit 1
    }
    Write-Host "[ok] LiteLLM listening on :$LiteLLMPort" -ForegroundColor Green
}

# --- 3. End-to-end health check ---
if ($SkipHealthCheck) { Write-Host "[done] (health check skipped)" -ForegroundColor Yellow; exit 0 }

$envFile = Join-Path $root ".env"
$masterKey = $null
foreach ($line in (Get-Content $envFile)) {
    if ($line -match '^LITELLM_MASTER_KEY=(.+)$') { $masterKey = $matches[1].Trim().Trim('"').Trim("'"); break }
}
if (-not $masterKey) { Write-Host "[warn] no LITELLM_MASTER_KEY in .env; skipping e2e check" -ForegroundColor Yellow; exit 0 }

Write-Host "[check] e2e: /v1/messages via LiteLLM -> copilot-api" -ForegroundColor Cyan
$body = @{
    model = "claude-sonnet-4-6-copilot"
    max_tokens = 20
    messages = @(@{ role = "user"; content = "Reply only: HEALTHY" })
} | ConvertTo-Json -Depth 5

try {
    $resp = Invoke-RestMethod -Method Post `
        -Uri "http://${BindHost}:${LiteLLMPort}/v1/messages" `
        -Headers @{ "x-api-key" = $masterKey; "anthropic-version" = "2023-06-01" } `
        -ContentType "application/json" `
        -Body $body `
        -TimeoutSec 30
    $text = $resp.content[0].text
    if ($text -match "HEALTHY") {
        Write-Host "[ok] e2e healthy: '$text'" -ForegroundColor Green
        Write-Host ""
        Write-Host "Gateway is UP." -ForegroundColor Green
        Write-Host "  Anthropic clients (Claude Code): ANTHROPIC_BASE_URL=http://${BindHost}:${LiteLLMPort}" -ForegroundColor White
        Write-Host "  OpenAI clients (Cursor):         OPENAI_API_BASE=http://${BindHost}:${LiteLLMPort}/v1" -ForegroundColor White
        Write-Host "  API key (both):                  $masterKey" -ForegroundColor White
        exit 0
    } else {
        Write-Host "[warn] e2e returned unexpected text: $text" -ForegroundColor Yellow
        exit 0
    }
} catch {
    Write-Host "[fail] e2e check failed: $_" -ForegroundColor Red
    exit 1
}
