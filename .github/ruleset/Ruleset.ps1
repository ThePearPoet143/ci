# https://docs.github.com/en/rest/repos/rules

function Read-Ruleset {
    [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ruleset.json')) | ConvertFrom-Json
}

function Get-RequiredCheck($Ruleset) {
    $rule = $Ruleset.rules | Where-Object type -EQ 'required_status_checks'
    @($rule.parameters.required_status_checks | ForEach-Object { $_.context })
}

function Test-BranchRule([string]$Branch, $Rules, $Ruleset) {
    $types = @($Rules | ForEach-Object { $_.type })
    foreach ($type in 'deletion', 'non_fast_forward') {
        if ($types -notcontains $type) { "${Branch}: no $type rule, so it can be deleted or force-pushed" }
    }
    $pull = $Rules | Where-Object type -EQ 'pull_request' | Select-Object -First 1
    if (-not $pull) {
        "${Branch}: no pull request rule, so changes can skip review"
    } else {
        if ($pull.parameters.required_approving_review_count -lt 1) { "${Branch}: needs at least one approval" }
        if (-not $pull.parameters.require_code_owner_review) { "${Branch}: needs code owner review" }
    }
    $present = @($Rules | Where-Object type -EQ 'required_status_checks' |
            ForEach-Object { $_.parameters.required_status_checks } | ForEach-Object { $_.context })
    foreach ($check in Get-RequiredCheck $Ruleset) {
        if ($present -notcontains $check) { "${Branch}: the $check check isn't required" }
    }
}
