# scripts/enable-wsl-firewall.ps1
# Run ONCE as Administrator to allow Windows host -> WSL2 mirrored-mode
# inbound on the AI-Gateway ports. Without this, Win 127.0.0.1:4000 is
# blocked by the Hyper-V VM firewall default-Block rule.
#
# Usage (in elevated PowerShell):
#   .\scripts\enable-wsl-firewall.ps1
#
# What it does:
#   Adds an allow rule for ports 4000 (LiteLLM), 4141 (copilot-api),
#   4002 (cost.html) on the WSL Hyper-V VM. Targeted, not blanket.
#
# Roll back:
#   Get-NetFirewallHyperVRule -DisplayName 'AI-Gateway' | Remove-NetFirewallHyperVRule

$ErrorActionPreference = 'Stop'

# Verify admin
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: must run in Administrator PowerShell." -ForegroundColor Red
    Write-Host "  Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    exit 1
}

# WSL VM CreatorId (固定 GUID for WSL2 Hyper-V VM)
$wsl = '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'

# Drop any pre-existing rule with same name (idempotent)
Get-NetFirewallHyperVRule -ErrorAction SilentlyContinue |
    Where-Object DisplayName -eq 'AI-Gateway' |
    Remove-NetFirewallHyperVRule -ErrorAction SilentlyContinue

New-NetFirewallHyperVRule `
    -DisplayName 'AI-Gateway' `
    -VMCreatorId $wsl `
    -Direction Inbound `
    -Action Allow `
    -LocalPorts 4000,4141,4002 `
    -Protocol TCP | Out-Null

Write-Host "[ok] Hyper-V firewall rule 'AI-Gateway' added for WSL ports 4000/4141/4002." -ForegroundColor Green
Write-Host ""
Write-Host "Verify (any PS shell, no admin):" -ForegroundColor Cyan
Write-Host '  curl.exe --noproxy "*" -s -o NUL -w "%{http_code}" http://127.0.0.1:4000/health/readiness' -ForegroundColor White
Write-Host "Should print 200." -ForegroundColor White
