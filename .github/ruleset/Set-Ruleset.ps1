# https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset
# https://docs.github.com/en/rest/repos/rules#update-a-repository-ruleset
# https://docs.github.com/en/rest/repos/repos#update-a-repository
param([string]$Repo = 'ThePearPoet143/ci')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Ruleset.ps1"

function Invoke-Gh {
    $out = & gh @args
    if ($LASTEXITCODE) { throw "gh $($args -join ' ') failed with exit code $LASTEXITCODE" }
    $out
}

$rulesets = @(Read-Ruleset $Repo)
$existing = @(((Invoke-Gh api "repos/$Repo/rulesets") -join "`n" | ConvertFrom-Json)) | ForEach-Object { $_ }
foreach ($ruleset in $rulesets) {
    $file = Join-Path ([IO.Path]::GetTempPath()) 'ruleset.json'
    [IO.File]::WriteAllText($file, ($ruleset | ConvertTo-Json -Depth 10))
    $match = $existing | Where-Object name -EQ $ruleset.name | Select-Object -First 1
    if ($match) {
        Invoke-Gh api -X PUT "repos/$Repo/rulesets/$($match.id)" --input $file --silent
        Write-Output "Updated rule set '$($ruleset.name)' on $Repo."
    } else {
        Invoke-Gh api -X POST "repos/$Repo/rulesets" --input $file --silent
        Write-Output "Created rule set '$($ruleset.name)' on $Repo."
    }
}
Invoke-Gh api -X PATCH "repos/$Repo" -F allow_auto_merge=true --silent
Write-Output "Auto-merge is allowed on $Repo."
foreach ($branch in 'dev', 'main') {
    $rules = @(((Invoke-Gh api "repos/$Repo/rules/branches/$branch") -join "`n" | ConvertFrom-Json)) | ForEach-Object { $_ }
    $problems = @(Test-BranchRule $branch $rules $rulesets)
    if ($problems) { $problems | ForEach-Object { Write-Output $_ } } else { Write-Output "${branch}: every rule is in force." }
}
