# https://github.com/cursor/plugins/blob/main/pstack/skills/correct/SKILL.md

function Read-RuleTable([string]$Text) {
    foreach ($line in $Text -split "`r?`n") {
        if ($line -notmatch '^\|' -or $line -match '^\|\s*-+\s*\|' -or $line -match '^\|\s*Rule\s*\|') { continue }
        $cells = @(($line.Trim().Trim('|') -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ge 2) { [pscustomobject]@{ Rule = $cells[0]; Enforcer = $cells[1] } }
    }
}

function Test-RuleEnforcer([string]$Enforcer, [string]$Root) {
    if ($Enforcer -match '^`([^`]+)`$') {
        if (-not (Test-Path (Join-Path $Root $Matches[1]))) { "Rule enforcer $Enforcer doesn't exist in ci" }
        return
    }
    if ($Enforcer -ceq 'judgment' -or $Enforcer -cmatch '^planned: HQ-\d+' -or $Enforcer -cmatch '^(GitHub|Linear|Claude Code): ') { return }
    "Rule enforcer '$Enforcer' names nothing checkable: use a path in ci, GitHub:, Linear:, Claude Code:, planned: HQ-n, or judgment"
}
