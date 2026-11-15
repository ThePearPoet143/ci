# What a merge into main releases (HQ-2, ported from foundation's SUS-45). release.yml runs Invoke-Release.ps1.
. "$PSScriptRoot\..\actions\text-check\TextCheck.ps1"

function Read-VersionedText {
    $root = Join-Path $PSScriptRoot '../..'
    $files = @(Join-Path $root 'README.md') + @(Get-ChildItem (Join-Path $root '.github/workflows') -Filter *.yml | ForEach-Object { $_.FullName })
    ($files | ForEach-Object { [IO.File]::ReadAllText($_) }) -join "`n"
}

function Get-ReleaseVersion([string]$Text) {
    $refs = @([regex]::Matches($Text, '(?i)ThePearPoet143/ci/[^@\s]+@([^\s''"]+)') | ForEach-Object { $_.Groups[1].Value })
    $loose = @($refs | Where-Object { $_ -cnotmatch '^v\d+\.\d+\.\d+$' } | Sort-Object -Unique)
    if ($loose) { throw "$(($loose | ForEach-Object { "@$_" }) -join ', ') isn't an exact version: calls to ci name vX.Y.Z" }
    $versions = @($refs | Sort-Object -Unique)
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

function Test-ReleasePr([string]$PrTitle, [string]$Version, [string[]]$Released) {
    $title = Get-ReleaseTitle $PrTitle $Version
    if ($Released -contains $Version) { throw "$Version is already released: a release PR names a new version" }
    $title
}

function Get-ReleaseNote([string]$Body) {
    $sections = ($Body.TrimEnd() -split "`r?`n" | Select-Object -SkipLast 1) -join "`n"
    $note = Get-Section $sections 'What and why'
    if (-not $note) { throw 'The release PR has no "## What and why" section for the notes' }
    $note -replace "`r`n", "`n"
}
