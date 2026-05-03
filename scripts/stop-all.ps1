# AI-Gateway: stop LiteLLM + copilot-api gracefully.
# Finds PIDs by port, sends SIGTERM (Stop-Process), waits, force-kills if needed.
#
# Usage:
#   .\scripts\stop-all.ps1              # stop both
#   .\scripts\stop-all.ps1 -OnlyLiteLLM
#   .\scripts\stop-all.ps1 -OnlyCopilot

param(
    [int]$LiteLLMPort = 4000,
    [int]$CopilotPort = 4141,
    [switch]$OnlyLiteLLM,
    [switch]$OnlyCopilot
)

function Stop-PortOwner {
    param([int]$Port, [string]$Label)
    $entries = netstat -ano | Select-String ":$Port\s+.*LISTENING"
    if (-not $entries) { Write-Host "[skip] ${Label}: nothing on :${Port}" -ForegroundColor DarkGray; return }

    $procIds = @()
    foreach ($e in $entries) {
        $parts = ($e.ToString() -split '\s+') | Where-Object { $_ }
        $candidatePid = $parts[-1]
        if ($candidatePid -match '^\d+$') { $procIds += [int]$candidatePid }
    }
    $procIds = $procIds | Sort-Object -Unique
    foreach ($targetPid in $procIds) {
        try {
            Stop-Process -Id $targetPid -Force -ErrorAction Stop
            Write-Host "[stop] ${Label} PID ${targetPid} (:${Port})" -ForegroundColor Cyan
        } catch {
            Write-Host "[warn] could not stop PID $targetPid : $_" -ForegroundColor Yellow
        }
    }
}

if (-not $OnlyCopilot) { Stop-PortOwner -Port $LiteLLMPort -Label "LiteLLM" }
if (-not $OnlyLiteLLM) { Stop-PortOwner -Port $CopilotPort -Label "copilot-api" }

Start-Sleep -Seconds 1
$liteUp = (netstat -ano | Select-String ":$LiteLLMPort\s+.*LISTENING") -ne $null
$cpUp   = (netstat -ano | Select-String ":$CopilotPort\s+.*LISTENING") -ne $null
if ($liteUp -or $cpUp) {
    Write-Host "[warn] some processes still listening: LiteLLM=$liteUp, copilot=$cpUp" -ForegroundColor Yellow
} else {
    Write-Host "[ok] gateway stopped." -ForegroundColor Green
}
