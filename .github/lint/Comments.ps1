. "$PSScriptRoot\..\actions\Git.ps1"

function Get-SourceFile([string]$Root) {
    $top = (Resolve-Path $Root).Path
    Invoke-Git -C $top ls-files '*.ps1' '*.psm1' '*.yml' |
        ForEach-Object { (Resolve-Path (Join-Path $top $_)).Path }
}

function Get-Comment([string]$Text, [string]$Name) {
    if ($Name -match '\.ya?ml$') {
        $lines = $Text -split "`r?`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*#') { [pscustomobject]@{ Line = $i + 1; Text = $lines[$i].Trim() } }
        }
        return
    }
    $tokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$null)
    foreach ($token in $tokens | Where-Object Kind -EQ 'Comment') {
        [pscustomobject]@{ Line = $token.Extent.StartLineNumber; Text = $token.Text.Trim() }
    }
}

function Find-CommentProblem([string]$Text, [string]$Name) {
    foreach ($comment in Get-Comment $Text $Name) {
        if ($comment.Text -match '^#\s*https://\S+$' -or $comment.Text -match '^#Requires\b') { continue }
        "${Name}:$($comment.Line): a comment is only a source link (# https://...); say the rest in the README or the pull request: $($comment.Text -split "`n" | Select-Object -First 1)"
    }
}

function Get-SourceLink([string]$Text, [string]$Name) {
    foreach ($comment in Get-Comment $Text $Name) {
        if ($comment.Text -match '^#\s*(https://\S+)$') { $Matches[1] }
    }
}

function Get-LinkToFetch([string]$Url) {
    if ($Url -match '^https://github\.com/([^/]+)/([^/]+)/blob/(.+)$') {
        return "https://raw.githubusercontent.com/$($Matches[1])/$($Matches[2])/$($Matches[3])"
    }
    $Url
}

function Test-SourceLink([string[]]$Url, [scriptblock]$Fetch) {
    foreach ($link in $Url | Sort-Object -Unique) {
        $problem = & $Fetch $link
        if ($problem) { "Source link ${link}: $problem" }
    }
}
