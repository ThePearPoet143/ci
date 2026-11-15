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

function ConvertFrom-IssuePage([string]$Json) {
    $response = $Json | ConvertFrom-Json
    if ($response.errors) { throw "Linear: $(@($response.errors | ForEach-Object { $_.message }) -join '; ')" }
    [pscustomobject]@{
        Issues      = @($response.data.issues.nodes)
        HasNextPage = [bool]$response.data.issues.pageInfo.hasNextPage
        EndCursor   = $response.data.issues.pageInfo.endCursor
    }
}
