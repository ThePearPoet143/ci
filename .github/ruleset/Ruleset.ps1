# https://docs.github.com/en/rest/repos/rules
# https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets

$RulesetOwner = 'ThePearPoet143'

function Read-Ruleset([string]$Repo) {
    if ($Repo -cnotmatch "^$RulesetOwner/[A-Za-z0-9._-]+$" -or $Repo -match '/\.\.?$') {
        throw "Rule sets here are for $RulesetOwner's repos, named $RulesetOwner/<name>, not $Repo"
    }
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

function Get-RulesetOrder($Rulesets, $Existing) {
    $planned = foreach ($ruleset in $Rulesets) {
        [pscustomobject]@{ Ruleset = $ruleset; Id = ($Existing | Where-Object name -EQ $ruleset.name | Select-Object -First 1).id }
    }
    @($planned | Where-Object { -not $_.Id }) + @($planned | Where-Object { $_.Id })
}

function Test-BranchRule([string]$Branch, $Rules, $Rulesets) {
    $expected = Get-BranchRuleset $Rulesets $Branch
    if (-not $expected) { throw "The repo's rule set file has none for $Branch" }
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

# https://docs.github.com/en/rest/deployments/environments#get-an-environment
# https://docs.github.com/en/rest/deployments/branch-policies#list-deployment-branch-policies
function Read-RulesetReviewer {
    $list = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'reviewers.json')) | ConvertFrom-Json
    $list | ForEach-Object { $_ }
}

function Test-RulesetEnvironment($Environment, $BranchPolicies, [string[]]$Allowed) {
    if (-not $Environment) { 'ci has no rulesets environment, so nothing guards the admin token (README, Rule set)'; return }
    $rule = $Environment.protection_rules | Where-Object type -EQ 'required_reviewers' | Select-Object -First 1
    $reviewers = @($rule.reviewers | ForEach-Object { if ($_.type -eq 'Team') { "team $($_.reviewer.slug)" } else { $_.reviewer.login } })
    if (-not $reviewers) { 'rulesets environment: no required reviewer, so the token is released without approval' }
    foreach ($name in $reviewers | Where-Object { $Allowed -notcontains $_ }) {
        "rulesets environment: $name is a reviewer but not on .github/ruleset/reviewers.json"
    }
    if ($rule.prevent_self_review) { 'rulesets environment: self-review is prevented, so the owner can''t approve their own run' }
    $policy = $Environment.deployment_branch_policy
    if (-not $policy) { 'rulesets environment: any branch may use it; allow only dev'; return }
    if ($policy.protected_branches -or -not $policy.custom_branch_policies) { 'rulesets environment: allow only the selected branch dev' }
    $names = @($BranchPolicies | ForEach-Object { "$($_.type) $($_.name)" })
    foreach ($extra in $names | Where-Object { $_ -ne 'branch dev' }) { "rulesets environment: $extra may use it; allow only dev" }
    if ($policy.custom_branch_policies -and $names -notcontains 'branch dev') { 'rulesets environment: dev isn''t allowed, so the workflow can''t run' }
}

function Test-RulesetSecret([string]$Visible) {
    if ($Visible -eq 'true') { 'RULESET_TOKEN is a repository secret, so any PR''s workflow can read it: keep it only in the rulesets environment' }
}

function Test-LatestDev([string]$Sha, [string]$DevHead) {
    if ($Sha -ne $DevHead) { "This run is at $Sha, not dev's latest commit ${DevHead}: start a new run instead of rerunning an old one" }
}
