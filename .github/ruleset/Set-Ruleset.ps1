# https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset
# https://docs.github.com/en/rest/repos/rules#update-a-repository-ruleset
param([string]$Repo = 'ThePearPoet143/ci')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Ruleset.ps1"

function Invoke-Gh {
    $out = & gh @args
    if ($LASTEXITCODE) { throw "gh $($args -join ' ') failed with exit code $LASTEXITCODE" }
    $out
}

$file = Join-Path $PSScriptRoot 'ruleset.json'
$name = (Read-Ruleset).name
$existing = @(((Invoke-Gh api "repos/$Repo/rulesets") -join "`n" | ConvertFrom-Json)) | ForEach-Object { $_ } | Where-Object name -EQ $name
if ($existing) {
    Invoke-Gh api -X PUT "repos/$Repo/rulesets/$($existing.id)" --input $file --silent
    Write-Output "Updated rule set '$name' on $Repo."
} else {
    Invoke-Gh api -X POST "repos/$Repo/rulesets" --input $file --silent
    Write-Output "Created rule set '$name' on $Repo."
}
foreach ($branch in 'dev', 'main') {
    $rules = @(((Invoke-Gh api "repos/$Repo/rules/branches/$branch") -join "`n" | ConvertFrom-Json)) | ForEach-Object { $_ }
    $problems = @(Test-BranchRule $branch $rules (Read-Ruleset))
    if ($problems) { $problems | ForEach-Object { Write-Output $_ } } else { Write-Output "${branch}: every rule is in force." }
}
