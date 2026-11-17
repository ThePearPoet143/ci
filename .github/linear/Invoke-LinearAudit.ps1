# https://linear.app/developers/graphql
# https://linear.app/developers/filtering
param([string]$Team = 'HQ', [string]$Key = $env:LINEAR_API_KEY)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Audit.ps1"
$skip = Get-AuditSkip $env:GITHUB_EVENT_NAME $Key
if ($skip) { Write-Output $skip; exit 0 }
if (-not $Key) { throw 'LINEAR_API_KEY is not set' }

function Invoke-Linear([string]$Query, [hashtable]$Variables) {
    $body = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Compress -Depth 5
    (Invoke-WebRequest 'https://api.linear.app/graphql' -Method Post -UseBasicParsing -ContentType 'application/json' -Headers @{ Authorization = $Key } -Body $body).Content
}

$teams = (Invoke-Linear (Get-TeamQuery) @{ team = $Team }) | ConvertFrom-Json
if ($teams.errors) { throw "Linear: $(@($teams.errors | ForEach-Object { $_.message }) -join '; ')" }
$visible = @($teams.data.teams.nodes).Count -gt 0
Write-Output "Key can see team ${Team}: $(if ($visible) { 'yes' } else { 'no' })"

$issues = @()
$after = $null
do {
    $page = ConvertFrom-IssuePage (Invoke-Linear (Get-IssueQuery) @{ team = $Team; after = $after })
    $issues += $page.Issues
    $after = $page.EndCursor
} while ($page.HasNextPage)

foreach ($issue in $issues | Sort-Object { [int]($_.identifier -replace '\D', '') }) { Write-Output (Format-AuditRead $issue) }
$problems = @(Get-AuditReadProblem $Team $visible $issues.Count) + @(foreach ($issue in $issues) { Find-IssueAuditProblem $issue })
$problems = @($problems | Where-Object { $_ })
$summary = @("Linear audit: $($issues.Count) open $Team issues read, $($problems.Count) problems.") + @($problems | ForEach-Object { "- $_" })
$summary | ForEach-Object { Write-Output $_ }
if ($env:GITHUB_STEP_SUMMARY) { Add-Content -Path $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Value $summary }
if ($problems) { exit 1 }
