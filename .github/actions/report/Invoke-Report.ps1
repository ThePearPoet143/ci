# https://docs.github.com/en/rest/issues/comments#update-an-issue-comment
param([string]$Repo = $env:REPO, [string]$Sha = $env:HEAD_SHA, [string]$Pr = $env:PR_NUMBER)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Report.ps1"

function Invoke-Gh {
    $out = & gh @args
    if ($LASTEXITCODE) { throw "gh $($args -join ' ') failed with exit code $LASTEXITCODE" }
    $out
}

if (-not $Pr) {
    $Pr = @(Invoke-Gh api "repos/$Repo/commits/$Sha/pulls" --jq '.[] | select(.state == "open") | .number') | Select-Object -First 1
}
if (-not $Pr) { Write-Output "No open pull request has $Sha as its head; nothing to report."; exit 0 }

$runs = @(Invoke-Gh api "repos/$Repo/commits/$Sha/check-runs" --paginate --jq '.check_runs[] | {name, status, conclusion, html_url}' | ForEach-Object { $_ | ConvertFrom-Json })
$statuses = @(Invoke-Gh api "repos/$Repo/commits/$Sha/statuses" --paginate --jq '.[] | {context, state, target_url, created_at}' | ForEach-Object { $_ | ConvertFrom-Json })
$rows = @(ConvertTo-ReportRow $runs $statuses)
Write-Output "Read PR #${Pr} at ${Sha}: $($runs.Count) check runs, $($statuses.Count) statuses, $($rows.Count) checks."

$body = Join-Path ([IO.Path]::GetTempPath()) 'ci-report.md'
[IO.File]::WriteAllText($body, (Format-CheckReport $rows $Sha.Substring(0, 7)))
$comments = @(Invoke-Gh api "repos/$Repo/issues/$Pr/comments" --paginate --jq '.[] | {id, body}' | ForEach-Object { $_ | ConvertFrom-Json })
$id = Get-ReportCommentId $comments
if ($id) {
    Invoke-Gh api -X PATCH "repos/$Repo/issues/comments/$id" -F "body=@$body" --silent
    Write-Output "Updated the report comment on PR #$Pr."
} else {
    Invoke-Gh api -X POST "repos/$Repo/issues/$Pr/comments" -F "body=@$body" --silent
    Write-Output "Posted the report comment on PR #$Pr."
}
