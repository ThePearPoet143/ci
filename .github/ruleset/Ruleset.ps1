# https://docs.github.com/en/rest/repos/rules
# https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets

function Read-Ruleset([string]$Repo) {
    $file = Join-Path $PSScriptRoot "repos/$(($Repo -split '/')[-1]).json"
    if (-not (Test-Path $file)) { throw "No rule set for ${Repo}: add $file" }
    $sets = [IO.File]::ReadAllText($file) | ConvertFrom-Json
    $sets | ForEach-Object { $_ }
}

function Get-BranchRuleset($Rulesets, [string]$Branch) {
    $Rulesets | Where-Object { $_.conditions.ref_name.include -contains "refs/heads/$Branch" } | Select-Object -First 1
}

function Get-RequiredCheck($Ruleset) {
    $rule = $Ruleset.rules | Where-Object type -EQ 'required_status_checks'
    @($rule.parameters.required_status_checks | ForEach-Object { $_.context })
}

function Test-BranchRule([string]$Branch, $Rules, $Rulesets) {
    $expected = Get-BranchRuleset $Rulesets $Branch
    $want = $expected.rules | Where-Object type -EQ 'pull_request'
    $types = @($Rules | ForEach-Object { $_.type })
    foreach ($type in 'deletion', 'non_fast_forward') {
        if ($types -notcontains $type) { "${Branch}: no $type rule, so it can be deleted or force-pushed" }
    }
    $pulls = @($Rules | Where-Object type -EQ 'pull_request')
    if (-not $pulls) {
        "${Branch}: no pull request rule, so changes can skip review"
    } else {
        $approvals = ($pulls | ForEach-Object { [int]$_.parameters.required_approving_review_count } | Measure-Object -Maximum).Maximum
        $needed = [int]$want.parameters.required_approving_review_count
        if ($approvals -lt $needed) { "${Branch}: needs $needed approval$(if ($needed -gt 1) { 's' }), has $approvals" }
        if ($want.parameters.require_code_owner_review -and -not ($pulls | Where-Object { $_.parameters.require_code_owner_review })) {
            "${Branch}: needs code owner review"
        }
    }
    $present = @($Rules | Where-Object type -EQ 'required_status_checks' |
            ForEach-Object { $_.parameters.required_status_checks } | ForEach-Object { $_.context })
    foreach ($check in Get-RequiredCheck $expected) {
        if ($present -notcontains $check) { "${Branch}: the $check check isn't required" }
    }
}
