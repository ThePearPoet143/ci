. "$PSScriptRoot\..\actions\text-check\TextCheck.ps1"

function Test-ReleasePr([string]$PrTitle, [string[]]$Released) {
    if ($PrTitle -cnotmatch '^chore\(release\): (v\d+\.\d+\.\d+), (.+?) \([A-Z]+-\d+\)$') {
        throw "A release PR's title is 'chore(release): vX.Y.Z, <what> (KEY-123)', not '$PrTitle'"
    }
    $version = $Matches[1]
    if ($Released -contains $version) { throw "$version is already released: a release PR names a new version" }
    [pscustomobject]@{ Version = $version; Title = "${version}: $($Matches[2])" }
}

function Get-ReleaseNote([string]$Body) {
    $sections = ($Body.TrimEnd() -split "`r?`n" | Select-Object -SkipLast 1) -join "`n"
    $note = Get-Section $sections 'Change'
    if (-not $note) { throw 'The release PR has no "## Change" section for the notes' }
    $note -replace "`r`n", "`n"
}
