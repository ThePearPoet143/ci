# https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch
# https://docs.github.com/en/rest/deployments/environments#get-an-environment
param([string]$Repo = $env:REPO)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Ruleset.ps1"

$rulesets = @(Read-Ruleset $Repo)
$problems = foreach ($branch in 'dev', 'main') {
    $raw = & gh api "repos/$Repo/rules/branches/$branch"
    if ($LASTEXITCODE) { throw "gh api repos/$Repo/rules/branches/$branch failed with exit code $LASTEXITCODE" }
    $rules = @(($raw -join "`n" | ConvertFrom-Json)) | ForEach-Object { $_ }
    Write-Output "Read $($rules.Count) rules in force on ${branch}: $(@($rules | ForEach-Object { $_.type }) -join ', ')" | Out-Host
    Test-BranchRule $branch $rules $rulesets
}
if ($Repo -eq 'ThePearPoet143/ci') {
    $environment = $null
    $policies = @()
    $names = @(& gh api "repos/$Repo/environments" --jq '.environments[].name')
    if ($LASTEXITCODE) { throw "gh api repos/$Repo/environments failed with exit code $LASTEXITCODE" }
    if ($names -contains 'rulesets') {
        $environment = (& gh api "repos/$Repo/environments/rulesets") -join "`n" | ConvertFrom-Json
        if ($LASTEXITCODE) { throw 'gh api .../environments/rulesets failed' }
        $listed = (& gh api "repos/$Repo/environments/rulesets/deployment-branch-policies") -join "`n" | ConvertFrom-Json
        if ($LASTEXITCODE) { throw 'gh api .../deployment-branch-policies failed' }
        $policies = @($listed.branch_policies | ForEach-Object { $_ })
    }
    $problems = @($problems) + @(Test-RulesetEnvironment $environment $policies @(Read-RulesetReviewer))
}
$problems = @($problems | Where-Object { $_ })
$problems | ForEach-Object { Write-Output $_ }
if ($problems) { Write-Output 'Rule set: run .github/ruleset/Set-Ruleset.ps1 as the repo owner (README, Rule set).'; exit 1 }
Write-Output 'Rule set: every rule is in force on dev and main.'
