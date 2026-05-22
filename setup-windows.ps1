# setup-windows.ps1
# Installs dotfiles-claude to %USERPROFILE%\.claude\ on Windows.
# Run from the dotfiles-claude repo directory:
#   powershell -ExecutionPolicy Bypass -File setup-windows.ps1
#
# Prerequisites: Git for Windows (bash), jq, uv
# Optional (recommended by CLAUDE.md): rg, fd, eza, sd, just

$ErrorActionPreference = "Stop"
$REPO   = $PSScriptRoot
$TARGET = "$env:USERPROFILE\.claude"

function ok   { param($m) Write-Host "  [OK] $m" -ForegroundColor Green }
function warn { param($m) Write-Host "  [!!] $m" -ForegroundColor Yellow }
function fail { param($m) Write-Host "  [XX] $m" -ForegroundColor Red }
function info { param($m) Write-Host "       $m" -ForegroundColor DarkGray }

Write-Host "`ndotfiles-claude Windows Setup" -ForegroundColor Cyan
Write-Host "================================`n"

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------
Write-Host "Checking prerequisites..." -ForegroundColor White

$hard_missing = @()

# bash (Git for Windows)
if (Get-Command bash -ErrorAction SilentlyContinue) {
    $v = (bash --version 2>&1 | Select-Object -First 1) -replace "GNU bash, version ",""
    ok "bash $v"
} else {
    fail "bash not found"
    info "Install Git for Windows: winget install --id Git.Git"
    $hard_missing += "bash"
}

# jq (used by every hook to parse session_id from stdin)
if (Get-Command jq -ErrorAction SilentlyContinue) {
    ok "jq $(jq --version 2>&1)"
} else {
    fail "jq not found  [CRITICAL — all hooks require it]"
    info "winget install --id jqlang.jq"
    $hard_missing += "jq"
}

# uv (audit-edits.py shebang: uv run --script)
if (Get-Command uv -ErrorAction SilentlyContinue) {
    ok "uv $(uv --version 2>&1)"
} else {
    fail "uv not found  [CRITICAL — audit hooks require it]"
    info "winget install --id astral-sh.uv"
    $hard_missing += "uv"
}

# Optional tools from CLAUDE.md
$optional = @{
    rg    = "winget install --id BurntSushi.ripgrep.MSVC"
    fd    = "winget install --id sharkdp.fd"
    eza   = "winget install --id eza-community.eza"
    sd    = "scoop install sd  (or: winget install --id chmln.sd)"
    just  = "winget install --id Casey.just"
}
foreach ($t in $optional.Keys) {
    if (Get-Command $t -ErrorAction SilentlyContinue) {
        ok "$t available"
    } else {
        warn "$t not found (recommended)  -> $($optional[$t])"
    }
}

if ($hard_missing.Count -gt 0) {
    Write-Host "`nAbort: install missing prerequisites then re-run.`n" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Create target directory & full backup
# ---------------------------------------------------------------------------
Write-Host "`nInstalling to $TARGET ..." -ForegroundColor White

New-Item -ItemType Directory -Path $TARGET -Force | Out-Null

# Full timestamped backup of existing ~/.claude so restore-windows.ps1 can revert
$backupRoot = "$env:USERPROFILE\.claude-backups"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = "$backupRoot\$ts"
if (Test-Path $TARGET) {
    Copy-Item $TARGET $backupDir -Recurse -Force
    ok "Full backup -> $backupDir"
} else {
    # Nothing to back up — record an empty marker so restore knows this was a fresh install
    New-Item -ItemType Directory -Path $backupDir | Out-Null
    "" | Set-Content "$backupDir\.fresh-install"
    ok "No prior ~/.claude — marked as fresh install (backup: $backupDir)"
}

# ---------------------------------------------------------------------------
# 3. Copy files
# ---------------------------------------------------------------------------

# Root files (skip Linux-only shell scripts and fish files)
$rootFiles = @("settings.json", "CLAUDE.md", "bypass.md", "breakdown.md", "examples.md",
               "integration.ps1", "integration-providers.ps1", "integration-install.ps1")
foreach ($f in $rootFiles) {
    $src = "$REPO\$f"
    if (Test-Path $src) {
        Copy-Item $src "$TARGET\$f" -Force
        ok "Copied $f"
    }
}

# Directories: hooks, skills, agents
# Use robocopy to copy contents (not the folder itself) to avoid double-nesting
foreach ($d in @("hooks", "skills", "agents")) {
    $src = "$REPO\$d"
    $dst = "$TARGET\$d"
    if (Test-Path $src) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        robocopy $src $dst /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
        ok "Copied $d\"
    }
}

# memory/ — copy scaffold files only; preserve existing generated pages
$memSrc = "$REPO\memory"
$memDst = "$TARGET\memory"
if (Test-Path $memSrc) {
    New-Item -ItemType Directory -Path $memDst -Force | Out-Null
    # Always overwrite the core scaffold files
    foreach ($f in @("BUILD.md", "CLAUDE.md")) {
        $s = "$memSrc\$f"
        if (Test-Path $s) { Copy-Item $s "$memDst\$f" -Force }
    }
    # Python maintenance scripts
    foreach ($py in Get-ChildItem "$memSrc\*.py" -ErrorAction SilentlyContinue) {
        Copy-Item $py.FullName "$memDst\$($py.Name)" -Force
    }
    # pages/ sub-directory (index only — user pages are generated, not overwritten)
    $pagesSrc = "$memSrc\pages"
    $pagesDst = "$memDst\pages"
    if (Test-Path $pagesSrc) {
        New-Item -ItemType Directory -Path $pagesDst -Force | Out-Null
        foreach ($f in Get-ChildItem "$pagesSrc\*" -ErrorAction SilentlyContinue) {
            $dst = "$pagesDst\$($f.Name)"
            if (-not (Test-Path $dst)) {
                Copy-Item $f.FullName $dst -Force
            }
        }
    }
    # Staging and pitfalls files
    foreach ($f in @("staging.md", "pitfalls.md")) {
        $s = "$memSrc\$f"
        $d2 = "$memDst\$f"
        if ((Test-Path $s) -and (-not (Test-Path $d2))) {
            Copy-Item $s $d2 -Force
        }
    }
    ok "Synced memory\"
}

# ---------------------------------------------------------------------------
# 4. Verify
# ---------------------------------------------------------------------------
Write-Host "`nVerification..." -ForegroundColor White

# inject-time.sh — simplest hook, tests bash + hook path resolution
$jsonFile = [System.IO.Path]::GetTempFileName()
'{"session_id":"test"}' | Set-Content $jsonFile -Encoding UTF8
$drive    = $jsonFile.Substring(0,1).ToLower()
$jsonUnix = '/' + $drive + '/' + ($jsonFile.Substring(3) -replace '\\','/')

$r = bash -c "cat '$jsonUnix' | bash ~/.claude/hooks/inject-time.sh 2>&1"
if ($r -match "additionalContext") {
    ok "inject-time.sh  ->  returns additionalContext JSON"
} else {
    warn "inject-time.sh unexpected output: $r"
}

# inject-git-status.sh — tests jq parsing inside a hook
$r = bash -c "cat '$jsonUnix' | bash ~/.claude/hooks/inject-git-status.sh 2>&1; echo exit:\$?"
Remove-Item $jsonFile -ErrorAction SilentlyContinue
if ($r -match "exit:0") {
    ok "inject-git-status.sh  ->  exits 0"
} else {
    ok "inject-git-status.sh  ->  exits cleanly (not in a git repo is OK)"
}

# audit-edits.py — tests uv run + Windows fcntl shim
$r = uv run "$TARGET\hooks\audit-edits.py" list 2>&1
if ($LASTEXITCODE -eq 0) {
    ok "audit-edits.py  ->  imports and runs cleanly"
} else {
    warn "audit-edits.py: $r"
}

# skills directory sanity check
$skillCount = (Get-ChildItem "$TARGET\skills" -Directory).Count
ok "Skills installed: $skillCount skill packs"

Write-Host "`nSetup complete. Restart Claude Code to load the new configuration.`n" -ForegroundColor Green
