# https://github.com/cursor/plugins/blob/main/pstack/skills/correct/SKILL.md

function Read-RuleTable([string]$Text) {
    $inFence = $false
    $inTable = $false
    foreach ($line in $Text -split "`r?`n") {
        if (-not $inTable) {
            if ($line -match '^\s*```') { $inFence = -not $inFence; continue }
            if (-not $inFence -and $line -match '^\s*\|\s*Rule\s*\|\s*Enforced by\s*\|') { $inTable = $true }
            continue
        }
        if ($line -notmatch '^\s*\|') { break }
        $cells = @(($line.Trim().Trim('|') -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
        if (-not ($cells | Where-Object { $_ -notmatch '^:?-+:?$' })) { continue }
        [pscustomobject]@{ Rule = $cells[0]; Enforcer = if ($cells.Count -ge 2) { $cells[1] } else { '' } }
    }
}

function Test-RuleEnforcer([string]$Enforcer, [string]$Root) {
    if ($Enforcer -match '^`([^`]*)`$') {
        $path = $Matches[1].Trim()
        if (-not $path -or $path -match '[*?\[\]]') { return "Rule enforcer $Enforcer isn't a plain path in ci" }
        $top = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        $full = [IO.Path]::GetFullPath((Join-Path $Root $path))
        if (-not $full.StartsWith($top, [StringComparison]::Ordinal) -or -not (Test-Path -LiteralPath $full)) {
            return "Rule enforcer $Enforcer doesn't exist in ci"
        }
        return
    }
    if ($Enforcer -ceq 'judgment' -or $Enforcer -cmatch '^planned: HQ-\d+$' -or $Enforcer -cmatch '^(GitHub|Linear|Claude Code): \S') { return }
    "Rule enforcer '$Enforcer' names nothing checkable: use a path in ci, GitHub:, Linear:, Claude Code:, planned: HQ-n, or judgment"
}
