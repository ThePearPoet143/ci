param(
    [string]$Base = $env:BASE_REF,
    [string]$Head = $env:HEAD_REF,
    [string]$BaseSha = $env:BASE_SHA,
    [string]$HeadSha = $env:HEAD_SHA,
    [string]$Body = $env:PR_BODY,
    [string]$IssuePrefix = $env:ISSUE_PREFIX,
    [string]$HeadRepo = $env:HEAD_REPO,
    [string]$Repo = $env:REPO
)
. "$PSScriptRoot\Branch.ps1"
. "$PSScriptRoot\..\Git.ps1"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$problems = @(Test-PrTarget $Base $Head $HeadRepo $Repo)
if (Test-IsRelease $Base $Head $HeadRepo $Repo) {
    $warning = Test-ReleaseIssueList $Body $IssuePrefix
    if ($warning) { Write-Output "::warning::$warning" }
} else {
    foreach ($subject in @(Invoke-Git log --format=%s "$BaseSha..$HeadSha")) { $problems += Test-CommitSubject $subject $IssuePrefix }
}
$problems = @($problems | Where-Object { $_ })
if ($problems.Count -eq 0) { Write-Output 'Branch and commit checks: pass.'; exit 0 }
$problems | ForEach-Object { Write-Output "Branch and commit checks: $_" }
exit 1