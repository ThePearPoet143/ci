# Publishes a release when a release PR merges into main (HQ-2): the tag and the GitHub release. Run by release.yml.
# https://cli.github.com/manual/gh_release_create
# https://docs.github.com/en/rest/commits/commits#list-pull-requests-associated-with-a-commit
param([string]$Sha = $env:SHA, [string]$Repo = $env:REPO)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Release.ps1"

$pulls = gh api "repos/$Repo/commits/$Sha/pulls"
if ($LASTEXITCODE -ne 0) { throw "gh api repos/$Repo/commits/$Sha/pulls failed" }
$pr = @(($pulls | ConvertFrom-Json)) |
    Where-Object { $_.merge_commit_sha -eq $Sha -and $_.base.ref -eq 'main' } | Select-Object -First 1
if (-not $pr) { Write-Output "No release PR merged as $Sha, so nothing to release."; exit 0 }

$version = Get-ReleaseVersion (Read-VersionedText)
$released = @(gh release list --repo $Repo --limit 1000 --json tagName --jq '.[].tagName')
if ($LASTEXITCODE -ne 0) { throw 'gh release list failed' }
if ($released -contains $version) {
    $tagged = gh api "repos/$Repo/commits/$version" --jq .sha
    if ($LASTEXITCODE -eq 0 -and $tagged -eq $Sha) { Write-Output "$version is already released from $Sha."; exit 0 }
}

$title = Test-ReleasePr $pr.title $version $released
$notes = Join-Path ([IO.Path]::GetTempPath()) 'release-notes.md'
[IO.File]::WriteAllText($notes, (Get-ReleaseNote $pr.body))
gh release create $version --repo $Repo --target $Sha --title $title --notes-file $notes
if ($LASTEXITCODE -ne 0) { throw "gh release create $version failed" }
Write-Output "Released $title"
