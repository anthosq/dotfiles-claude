# restore-windows.ps1
# Restores ~/.claude to a backup created by setup-windows.ps1.
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File restore-windows.ps1
# Or to restore a specific backup:
#   powershell -ExecutionPolicy Bypass -File restore-windows.ps1 -BackupName 20240522-143000

param(
    [string]$BackupName = ""   # optional: exact timestamp folder name to restore
)

$ErrorActionPreference = "Stop"
$TARGET     = "$env:USERPROFILE\.claude"
$backupRoot = "$env:USERPROFILE\.claude-backups"

function ok   { param($m) Write-Host "  [OK] $m" -ForegroundColor Green }
function warn { param($m) Write-Host "  [!!] $m" -ForegroundColor Yellow }
function fail { param($m) Write-Host "  [XX] $m" -ForegroundColor Red }

Write-Host "`ndotfiles-claude Windows Restore" -ForegroundColor Cyan
Write-Host "=================================`n"

# ---------------------------------------------------------------------------
# 1. Find available backups
# ---------------------------------------------------------------------------
if (-not (Test-Path $backupRoot)) {
    fail "No backups found at $backupRoot — setup-windows.ps1 has not been run yet."
    exit 1
}

$backups = Get-ChildItem $backupRoot -Directory | Sort-Object Name -Descending
if ($backups.Count -eq 0) {
    fail "Backup directory exists but is empty: $backupRoot"
    exit 1
}

if ($BackupName -ne "") {
    $chosen = $backups | Where-Object { $_.Name -eq $BackupName }
    if (-not $chosen) {
        fail "Backup '$BackupName' not found in $backupRoot"
        Write-Host "`nAvailable backups:"
        $backups | ForEach-Object { Write-Host "  $($_.Name)" }
        exit 1
    }
} else {
    # Default: latest backup
    $chosen = $backups[0]
    Write-Host "Available backups:"
    $backups | ForEach-Object {
        $marker = if ($_.Name -eq $chosen.Name) { " <- will restore" } else { "" }
        Write-Host "  $($_.Name)$marker"
    }
    Write-Host ""
}

$backupDir = $chosen.FullName
Write-Host "Restoring from: $backupDir`n"

# ---------------------------------------------------------------------------
# 2. Confirm
# ---------------------------------------------------------------------------
$ans = Read-Host "This will REPLACE your current ~/.claude with the backup. Continue? [y/N]"
if ($ans -notmatch "^[yY]") {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# 3. Check if this was a fresh-install backup (nothing to restore)
# ---------------------------------------------------------------------------
if (Test-Path "$backupDir\.fresh-install") {
    Write-Host "`nThis backup was taken before any ~/.claude existed (fresh install)."
    $ans2 = Read-Host "Remove current ~/.claude entirely? [y/N]"
    if ($ans2 -notmatch "^[yY]") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
    Remove-Item $TARGET -Recurse -Force
    ok "Removed ~/.claude (restored to pre-install state)"
    Write-Host "`nRestore complete.`n" -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# 4. Restore
# ---------------------------------------------------------------------------
# Save a safety snapshot of the current state before overwriting
$safeTs  = Get-Date -Format "yyyyMMdd-HHmmss"
$safeDst = "$backupRoot\pre-restore-$safeTs"
if (Test-Path $TARGET) {
    Copy-Item $TARGET $safeDst -Recurse -Force
    ok "Safety snapshot of current state -> $safeDst"
}

# Replace ~/.claude with backup
Remove-Item $TARGET -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $backupDir $TARGET -Recurse -Force
ok "Restored ~/.claude from $($chosen.Name)"

Write-Host "`nRestore complete. Restart Claude Code to apply.`n" -ForegroundColor Green
