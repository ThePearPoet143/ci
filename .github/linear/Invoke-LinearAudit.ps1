# https://linear.app/developers/graphql
# https://linear.app/developers/filtering
param([string]$Team = 'HQ', [string]$Key = $env:LINEAR_API_KEY)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Audit.ps1"
if (-not $Key) { throw 'LINEAR_API_KEY is not set' }

$query = 'query($team: String!, $after: String) { issues(first: 50, after: $after, filter: { team: { key: { eq: $team } }, state: { type: { nin: ["completed", "canceled"] } } }) { nodes { identifier title description updatedAt } pageInfo { hasNextPage endCursor } } }'
$issues = @()
$after = $null
do {
    $body = @{ query = $query; variables = @{ team = $Team; after = $after } } | ConvertTo-Json -Compress -Depth 5
    $response = Invoke-WebRequest 'https://api.linear.app/graphql' -Method Post -UseBasicParsing -ContentType 'application/json' -Headers @{ Authorization = $Key } -Body $body
    $page = ConvertFrom-IssuePage $response.Content
    $issues += $page.Issues
    $after = $page.EndCursor
} while ($page.HasNextPage)

foreach ($issue in $issues | Sort-Object { [int]($_.identifier -replace '\D', '') }) {
    Write-Output "Read $($issue.identifier), updated $($issue.updatedAt): $($issue.title)"
}
$problems = @(foreach ($issue in $issues) { Find-IssueAuditProblem $issue })
$summary = @("Linear audit: $($issues.Count) open $Team issues read, $($problems.Count) problems.") + @($problems | ForEach-Object { "- $_" })
$summary | ForEach-Object { Write-Output $_ }
if ($env:GITHUB_STEP_SUMMARY) { Add-Content -Path $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Value $summary }
if ($problems) { exit 1 }
