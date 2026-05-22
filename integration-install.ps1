# integration-install.ps1
# Wires integration.ps1 (and optionally integration-providers.ps1) into your
# PowerShell profile. Idempotent — re-running adds nothing if already present.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File integration-install.ps1

$ErrorActionPreference = "Stop"
$claudeDir = "$env:USERPROFILE\.claude"

function ok   { param($m) Write-Host "  [OK] $m" -ForegroundColor Green }
function warn { param($m) Write-Host "  [!!] $m" -ForegroundColor Yellow }
function info { param($m) Write-Host "       $m" -ForegroundColor DarkGray }

Write-Host "`ndotfiles-claude Integration Installer" -ForegroundColor Cyan
Write-Host "======================================`n"

# Detect the active PowerShell profile file
$profilePath = $PROFILE.CurrentUserCurrentHost
Write-Host "PowerShell profile: $profilePath`n"

# Ensure profile file exists
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    info "Created new profile at $profilePath"
}

function Add-LineIfMissing {
    param([string]$File, [string]$Line, [string]$Label)
    $content = Get-Content $File -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -match [regex]::Escape($Line)) {
        ok "$Label already present"
    } else {
        Add-Content $File "`n$Line"
        ok "Added $Label to profile"
    }
}

# Core integration
$coreLine = ". `"$claudeDir\integration.ps1`""
$ans = Read-Host "Add core integration (claude/opus/sonnet/haiku/commit shortcuts)? [Y/n]"
if ($ans -match '^[nN]') {
    warn "Skipped core integration"
} else {
    Add-LineIfMissing $profilePath $coreLine "core integration"
}

# Provider shortcuts
$provLine = ". `"$claudeDir\integration-providers.ps1`""
$ans = Read-Host "Add provider shortcuts (glm/deepseek/qwen/openrouter/ofox)? [y/N]"
if ($ans -match '^[yY]') {
    Add-LineIfMissing $profilePath $provLine "provider shortcuts"
} else {
    warn "Skipped provider shortcuts"
}

Write-Host "`nDone. Reload your profile with:" -ForegroundColor Green
Write-Host "  . `$PROFILE" -ForegroundColor Cyan
