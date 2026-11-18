. "$PSScriptRoot\..\actions\text-check\TextCheck.ps1"

function Test-ReleasePr([string]$PrTitle, [string[]]$Released) {
    $release = Get-ReleaseTitle $PrTitle
    if (-not $release) { throw "A release PR's title is 'chore(release): vX.Y.Z, <what> (KEY-123)', not '$PrTitle'" }
    if ($Released -contains $release.Version) { throw "$($release.Version) is already released: a release PR names a new version" }
    [pscustomobject]@{ Version = $release.Version; Title = "$($release.Version): $($release.What)" }
}

function Find-FixedCiRef([string]$Text) {
    @([regex]::Matches($Text, '(?i)ThePearPoet143/ci[^\s@]*@(?!vX\.Y\.Z)[^\s''"`)]+') | ForEach-Object { $_.Value })
}

function Select-TagAt($Tags, [string]$Sha) {
    @($Tags | Where-Object { $_.commit.sha -eq $Sha } | ForEach-Object { $_.name })
}

function Get-ReleaseNote([string]$Body) {
    $sections = ($Body.TrimEnd() -split "`r?`n" | Select-Object -SkipLast 1) -join "`n"
    $note = Get-Section $sections 'Change'
    if (-not $note) { throw 'The release PR has no "## Change" section for the notes' }
    $note -replace "`r`n", "`n"
}
