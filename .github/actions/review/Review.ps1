# https://docs.github.com/en/rest/commits/statuses
. "$PSScriptRoot\..\text-check\TextCheck.ps1"

$ReviewMarker = '<!-- review:ai -->'
$ReviewVerdict = '^(Fixed in ([0-9a-f]{7,40})|By design|Noted|Not needed yet|Wrong)\b'

function Get-ReviewNeed([string[]]$Labels, [string]$Base) {
    $Base -cne 'main' -and $Labels -contains 'review:ai'
}

function Find-ReviewComment($Comments) {
    @($Comments | Where-Object { ([string]$_.body).TrimStart().StartsWith($ReviewMarker) } |
            Sort-Object { [datetime]$_.created_at }) | Select-Object -Last 1
}

function Test-ReviewComment([string]$Body, [string[]]$Commits) {
    $lines = @(($Body.Trim() -split "`r?`n") | ForEach-Object { $_.Trim() })
    $count = $lines | Where-Object { $_ } | Select-Object -Skip 1 -First 1
    if ($count -notmatch '^\*\*AI reviews?: (\d+) findings?\b') {
        "Review: the line after the marker is the count, e.g. '**AI review: 3 findings, 2 fixed, 1 noted.**'"
    }
    $expected = if ($Matches) { [int]$Matches[1] } else { -1 }

    $rows = @($lines | Where-Object { $_ -match '^\|\s*\d+\s*\|' })
    if ($expected -ge 0 -and $rows.Count -ne $expected) { "Review: the count says $expected findings, but the table has $($rows.Count) rows" }
    foreach ($row in $rows) {
        $cells = @(($row.Trim('|') -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne 4) { "Review: row '$row' needs 4 cells: #, Finding, Verdict, Evidence"; continue }
        if ($cells[2] -notmatch $ReviewVerdict) {
            "Review: finding $($cells[0])'s verdict '$($cells[2])' isn't one of: Fixed in <commit>, By design, Noted, Not needed yet, Wrong"
        } elseif ($Matches[2] -and -not ($Commits | Where-Object { $_.StartsWith($Matches[2]) })) {
            "Review: finding $($cells[0]) is Fixed in $($Matches[2]), which isn't a commit on this pull request"
        }
    }

    if (($n = Get-WordCount $Body) -gt 250) { "Review: $n words, over 250" }
    $last = $lines[-1]
    if (-not $last.StartsWith($Robot) -or $last -notmatch '\d') { "Review: Last line: $Robot, then the model and its version" }
}
