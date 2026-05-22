# integration-providers.ps1
# Provider shortcuts that route claude through third-party Anthropic-compatible
# endpoints. Source this after integration.ps1:
#   . "$env:USERPROFILE\.claude\integration-providers.ps1"
#
# Set the corresponding API key env var to enable each shortcut:
#   $env:ZAI_API_KEY        → glm       (Zhipu BigModel)
#   $env:DEEPSEEK_API_KEY   → deepseek
#   $env:OPENROUTER_API_KEY → openrouter
#   $env:OFOX_API_KEY       → ofox      (OfoxAI aggregator)
#   $env:LLAMA_API_KEY      → qwen
#
# Provider configs live in ~/.claude/providers/<name>.json

function Invoke-ClaudeWith {
    param(
        [Parameter(Mandatory)][string]$Provider,
        [Parameter(ValueFromRemainingArguments)][string[]]$Rest
    )

    $token = switch ($Provider) {
        "glm"        { $env:ZAI_API_KEY }
        "deepseek"   { $env:DEEPSEEK_API_KEY }
        "openrouter" { $env:OPENROUTER_API_KEY }
        "ofox"       { $env:OFOX_API_KEY }
        "qwen"       { $env:LLAMA_API_KEY }
        default {
            Write-Error "Invoke-ClaudeWith: unknown provider '$Provider'"
            return
        }
    }

    if (-not $token) {
        Write-Warning "No API key set for provider '$Provider' — check the env var listed in integration-providers.ps1."
    }

    $settingsPath = "$env:USERPROFILE\.claude\providers\$Provider.json"
    if (-not (Test-Path $settingsPath)) {
        Write-Error "Provider config not found: $settingsPath"
        return
    }

    $prevToken = $env:ANTHROPIC_AUTH_TOKEN
    $env:ANTHROPIC_AUTH_TOKEN = $token
    try {
        claude --settings $settingsPath @Rest
    } finally {
        $env:ANTHROPIC_AUTH_TOKEN = $prevToken
    }
}

function glm        { Invoke-ClaudeWith glm        @args }
function deepseek   { Invoke-ClaudeWith deepseek   @args }
function openrouter { Invoke-ClaudeWith openrouter @args }
function ofox       { Invoke-ClaudeWith ofox       @args }
function qwen       { Invoke-ClaudeWith qwen       @args }
