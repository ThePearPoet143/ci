# https://linear.app/developers/pagination
# https://github.com/linear/linear/blob/master/packages/sdk/src/schema.graphql
. "$PSScriptRoot\..\actions\text-check\TextCheck.ps1"

$IssueQuery = 'query($team: String!, $after: String) { issues(first: 50, after: $after, filter: { team: { key: { eq: $team } }, state: { type: { nin: ["completed", "canceled", "duplicate"] } } }) { nodes { identifier title description updatedAt } pageInfo { hasNextPage endCursor } } }'
$TeamQuery = 'query($team: String!) { teams(filter: { key: { eq: $team } }) { nodes { key } } }'

function Get-IssueBody([string]$Description) {
    ($Description -replace '(?ms)^(\+\+\+|>>>) *Agent notes.*?^\1 *$', '' -replace '(?ms)^(\+\+\+|>>>) *Agent notes.*\z', '').Trim()
}

function Find-IssueAuditProblem($Issue) {
    foreach ($problem in Test-IssueText ([string]$Issue.title) (Get-IssueBody ([string]$Issue.description))) {
        "$($Issue.identifier): $problem"
    }
}

function Format-AuditRead($Issue) {
    "Read $($Issue.identifier), updated $($Issue.updatedAt)"
}

function Get-AuditSkip([string]$EventName, [string]$Key) {
    if ($EventName -eq 'pull_request' -and -not $Key) {
        'Linear audit skipped: a pull request from a fork gets no LINEAR_API_KEY.'
    }
}

function Get-AuditReadProblem([string]$Team, [bool]$TeamVisible, [int]$IssueCount) {
    if (-not $TeamVisible) { return "Linear audit: this key can't see team $Team; give the key access to it" }
    if ($IssueCount -eq 0) { "Linear audit: read no open issues in team $Team, so it checked nothing" }
}

function ConvertFrom-IssuePage([string]$Json) {
    $response = $Json | ConvertFrom-Json
    if ($response.errors) { throw "Linear: $(@($response.errors | ForEach-Object { $_.message }) -join '; ')" }
    [pscustomobject]@{
        Issues      = @($response.data.issues.nodes)
        HasNextPage = [bool]$response.data.issues.pageInfo.hasNextPage
        EndCursor   = $response.data.issues.pageInfo.endCursor
    }
}
