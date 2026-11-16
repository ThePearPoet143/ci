# https://linear.app/developers/pagination
. "$PSScriptRoot\..\actions\text-check\TextCheck.ps1"

function Get-IssueBody([string]$Description) {
    ($Description -split '(?m)^(?:\+\+\+|>>>) *Agent notes')[0].TrimEnd()
}

function Find-IssueAuditProblem($Issue) {
    foreach ($problem in Test-IssueText ([string]$Issue.title) (Get-IssueBody ([string]$Issue.description))) {
        "$($Issue.identifier): $problem"
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
