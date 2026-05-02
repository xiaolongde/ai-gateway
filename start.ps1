# AI-Gateway launcher (Windows PowerShell, pure ASCII for reliability)
# Loads .env then starts LiteLLM Proxy in foreground.

param(
    [int]$Port = 4000,
    [string]$BindHost = "127.0.0.1"
)

$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

# Force Python to use UTF-8 (avoid GBK decoder errors on CN Windows)
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

# 1. Check .env
$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: missing .env. Copy from .env.example and fill keys." -ForegroundColor Red
    exit 1
}

# 2. Load .env into current process
foreach ($line in (Get-Content $envFile)) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
    $idx = $trimmed.IndexOf('=')
    if ($idx -le 0) { continue }
    $name = $trimmed.Substring(0, $idx).Trim()
    $value = $trimmed.Substring($idx + 1).Trim().Trim('"').Trim("'")
    if ($name -and $value) {
        Set-Item -Path "env:$name" -Value $value
    }
}

# 3. Check venv
$litellm = Join-Path $root ".venv\Scripts\litellm.exe"
if (-not (Test-Path $litellm)) {
    Write-Host "ERROR: venv missing. Run 'uv sync' first." -ForegroundColor Red
    exit 1
}

# 4. Launch
Write-Host "Starting LiteLLM Proxy on http://${BindHost}:${Port}" -ForegroundColor Green
Write-Host "Master key (for clients): $env:LITELLM_MASTER_KEY"
Write-Host ""

& $litellm --config (Join-Path $root "config.yaml") --port $Port --host $BindHost
