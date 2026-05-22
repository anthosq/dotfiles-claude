# integration.ps1
# PowerShell integration for Claude Code (Windows Terminal).
# Source this in your PowerShell profile via integration-install.ps1, or manually:
#   . "$env:USERPROFILE\.claude\integration.ps1"

# Resolve the real claude executable once at load time so the claude() wrapper
# can call it without recursing into itself.
$_claudeCmd = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue
$script:_claudeExe = if ($_claudeCmd) { $_claudeCmd.Source } else { $null }

function claude {
    <#
    .SYNOPSIS
    Claude Code wrapper: sets session ID, bash path, and PYTHONUNBUFFERED.
    #>
    if (-not $script:_claudeExe) {
        Write-Error "claude not found in PATH. Install Claude Code first."
        return 1
    }
    $session = "$(Split-Path $PWD -Leaf)-$('{0:x8}{1:x8}' -f (Get-Random), (Get-Random))"
    $bashCmd  = Get-Command bash -CommandType Application -ErrorAction SilentlyContinue

    $prev = @{
        SHELL                = $env:SHELL
        PYTHONUNBUFFERED     = $env:PYTHONUNBUFFERED
        AGENT_BROWSER_SESSION = $env:AGENT_BROWSER_SESSION
    }
    $env:SHELL                 = if ($bashCmd) { $bashCmd.Source } else { $env:SHELL }
    $env:PYTHONUNBUFFERED      = "1"
    $env:AGENT_BROWSER_SESSION = $session

    try {
        & $script:_claudeExe --thinking-display summarized --allow-dangerously-skip-permissions @args
    } finally {
        $env:SHELL                 = $prev.SHELL
        $env:PYTHONUNBUFFERED      = $prev.PYTHONUNBUFFERED
        $env:AGENT_BROWSER_SESSION = $prev.AGENT_BROWSER_SESSION
    }
}

function opus      { claude --model opus @args }
function opusplan  { claude --model opusplan --permission-mode plan @args }
function sonnet    { claude --model sonnet @args }
function haiku     { claude --model haiku @args }

function commit {
    <#
    .SYNOPSIS
    Auto git-commit using claude haiku — stages all changes and writes the message.
    .EXAMPLE
    commit
    commit "focus on the new auth flow"
    #>
    param([Parameter(ValueFromRemainingArguments)][string[]]$Note)

    if (-not $script:_claudeExe) {
        Write-Error "claude not found in PATH."
        return 1
    }

    $extra  = if ($Note) { " Additional user note to help you understand: $($Note -join ' ')" } else { "" }
    $prompt = "Make a git commit with commit message briefly describing what changed in the codebase. Stage and commit all changed files (including untracked ones). If some stagable files looks like should appear in .gitignore, add the file name pattern to .gitignore before stage. Do not edit files in this conversation.$extra"

    $prev = @{
        CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT      = $env:CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT
        CLAUDE_CODE_DISABLE_POLICY_SKILLS     = $env:CLAUDE_CODE_DISABLE_POLICY_SKILLS
        CLAUDE_CODE_DISABLE_AUTO_MEMORY       = $env:CLAUDE_CODE_DISABLE_AUTO_MEMORY
        ENABLE_CLAUDEAI_MCP_SERVERS           = $env:ENABLE_CLAUDEAI_MCP_SERVERS
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
        AUDIT_BACKEND                         = $env:AUDIT_BACKEND
    }
    $env:CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT         = "1"
    $env:CLAUDE_CODE_DISABLE_POLICY_SKILLS        = "1"
    $env:CLAUDE_CODE_DISABLE_AUTO_MEMORY          = "1"
    $env:ENABLE_CLAUDEAI_MCP_SERVERS              = "false"
    $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
    $env:AUDIT_BACKEND                            = "none"

    try {
        & $script:_claudeExe -p --model haiku --max-turns 50 $prompt
    } finally {
        foreach ($k in $prev.Keys) { Set-Item "env:$k" $prev[$k] }
    }
}
