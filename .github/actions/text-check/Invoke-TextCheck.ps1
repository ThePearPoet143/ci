param(
    [string]$Title = $env:PR_TITLE,
    [string]$Body = $env:PR_BODY,
    [string]$IssuePrefix = $env:ISSUE_PREFIX,
    [string]$IssueTitle,
    [string]$IssueBody
)
. "$PSScriptRoot\TextCheck.ps1"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$problems = if ($PSBoundParameters.ContainsKey('IssueTitle')) {
    @(Test-IssueText $IssueTitle $IssueBody)
} else {
    @(Test-PrTitle $Title $IssuePrefix) + @(Test-PrBody (Get-PrType $Title) $Body)
}
$problems = @($problems | Where-Object { $_ })

if ($problems.Count -eq 0) { Write-Output 'Text check: passes.'; exit 0 }
$problems | ForEach-Object { Write-Output "Text check: $_" }
exit 1