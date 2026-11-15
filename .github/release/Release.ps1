# What a merge into main releases (HQ-2, ported from foundation's SUS-45). release.yml runs Invoke-Release.ps1.
. "$PSScriptRoot\..\actions\text-check\TextCheck.ps1"

function Read-VersionedText {
    $root = Join-Path $PSScriptRoot '../..'
    $files = @(Join-Path $root 'README.md') + @(Get-ChildItem (Join-Path $root '.github/workflows') -Filter *.yml | ForEach-Object { $_.FullName })
    ($files | ForEach-Object { [IO.File]::ReadAllText($_) }) -join "`n"
}

function Get-ReleaseVersion([string]$Text) {
    $versions = @([regex]::Matches($Text, 'ThePearPoet143/ci/[^@\s]+@(v\d+\.\d+\.\d+)') |
            ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if ($versions.Count -eq 0) { throw 'The README and workflows call ci at no version' }
    if ($versions.Count -gt 1) { throw "The README and workflows call ci at more than one version: $($versions -join ', ')" }
    $versions[0]
}

function Get-ReleaseTitle([string]$PrTitle, [string]$Version) {
    if ($PrTitle -notmatch '^chore\(release\): (v\d+\.\d+\.\d+), (.+?) \([A-Z]+-\d+\)$') {
        throw "A release PR's title is 'chore(release): <version>, <what> (KEY-123)', not '$PrTitle'"
    }
    if ($Matches[1] -ne $Version) { throw "The release PR's title names $($Matches[1]), but the calls name $Version" }
    "${Version}: $($Matches[2])"
}

function Get-ReleaseNote([string]$Body) {
    $sections = ($Body.TrimEnd() -split "`r?`n" | Select-Object -SkipLast 1) -join "`n"
    $note = Get-Section $sections 'What and why'
    if (-not $note) { throw 'The release PR has no "## What and why" section for the notes' }
    $note -replace "`r`n", "`n"
}
