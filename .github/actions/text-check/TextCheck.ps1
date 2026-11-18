# https://www.conventionalcommits.org/en/v1.0.0/
$PrTypes = 'feat', 'fix', 'docs', 'chore', 'refactor', 'test', 'ci', 'build', 'perf', 'style'
$Robot = [char]::ConvertFromUtf32(0x1F916)

function Get-WordCount([string]$Text) {
    @([regex]::Matches($Text, '[\p{L}\p{N}][\p{L}\p{N}''\u2019.\-_/]*')).Count
}

function Get-PrType([string]$Title) {
    if ($Title -cmatch '^([a-z]+)(\([a-z0-9.\-]+\))?!?: ') { $Matches[1] }
}

function Test-PrTitle([string]$Title, [string]$IssuePrefix) {
    $type = Get-PrType $Title
    if (-not $type -or $PrTypes -cnotcontains $type) {
        "Title: start with a type ($($PrTypes -join ', ')), an optional (scope), then ': ', e.g. 'feat(doctor): ...'"
    }
    if ($Title -cnotmatch "\($IssuePrefix-\d+\)$") { "Title: end with the issue key in brackets, e.g. ($IssuePrefix-123)" }
    if ($Title.Length -gt 72) { "Title: $($Title.Length) characters, over 72" }
}

function Get-Section([string]$Body, [string]$Heading) {
    $m = [regex]::Match($Body, "(?ms)^##\s+$([regex]::Escape($Heading))[^\n]*\n(.*?)(?=^##\s|\z)")
    if ($m.Success) { $m.Groups[1].Value.Trim() } else { $null }
}

function Test-PrBody([string]$Type, [string]$Body) {
    $lines = $Body.TrimEnd() -split "`r?`n"
    $last = $lines[-1].Trim()
    $sections = ($lines | Select-Object -SkipLast 1) -join "`n"
    $found = @{}
    foreach ($name in 'Problem', 'Change', 'Scope', 'Verification') {
        $found[$name] = Get-Section $sections $name
        if ([string]::IsNullOrWhiteSpace($found[$name])) { "Description: needs a ""## $name"" section" }
    }
    if (($n = Get-WordCount "$($found.Problem) $($found.Change)") -gt 120) { "Problem and Change: $n words, over 120" }

    $verification = [string]$found.Verification
    if ($verification -and $verification -notmatch '(?im)^\W*Not checked:[ \t]*\S') {
        'Verification: add a "Not checked:" line saying what you couldn''t check, or why nothing was left'
    }
    if ($Type -eq 'fix' -and $verification -notmatch '(?i)\bRed\b') { 'Verification: a fix names the Red step, the test that failed before it' }

    $example = "'$Robot Claude Opus 5.5 · Claude Code'"
    if (-not $last.StartsWith($Robot)) { "Last line: $Robot, the model and its version, then the tool, e.g. $example" }
    elseif ($last -notmatch '^\S+ [^·]*\d[^·]* · \S') {
        if ($last -notmatch '\d') { "Last line: name the model's version, e.g. $example" }
        else { "Last line: name the tool after ' · ', e.g. $example" }
    }
}

function Test-IssueText([string]$Title, [string]$Body) {
    if ($Title.Length -gt 60) { "Issue title: $($Title.Length) characters, over 60" }
    if (($n = Get-WordCount $Body) -gt 80) { "Issue body: $n words, over 80" }
    if ($Body -notmatch '(?i)\bDone when\b') { 'Issue body: needs a "Done when"' }
}