# https://docs.github.com/en/rest/commits/statuses#create-a-commit-status
# https://docs.github.com/en/rest/issues/comments#list-issue-comments
param([string]$Repo = $env:REPO, [string]$Pr = $env:PR_NUMBER)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Review.ps1"

function Invoke-Gh {
    $out = & gh @args
    if ($LASTEXITCODE) { throw "gh $($args -join ' ') failed with exit code $LASTEXITCODE" }
    $out
}

$pull = (Invoke-Gh api "repos/$Repo/pulls/$Pr") -join "`n" | ConvertFrom-Json
$labels = @($pull.labels | ForEach-Object { $_.name })
$sha = $pull.head.sha
Write-Output "Read PR #${Pr}: base $($pull.base.ref), head $sha, labels: $($labels -join ', ')"

if (-not (Get-ReviewNeed $labels $pull.base.ref)) {
    $state = 'success'; $description = 'No review needed'
} else {
    $commits = @(Invoke-Gh api "repos/$Repo/pulls/$Pr/commits" --paginate --jq '.[].sha')
    $comments = @(Invoke-Gh api "repos/$Repo/issues/$Pr/comments" --paginate --jq '.[] | {body, created_at, user: .user.login}' | ForEach-Object { $_ | ConvertFrom-Json })
    Write-Output "Read $($commits.Count) commits and $($comments.Count) comments"
    $review = Find-ReviewComment $comments
    $problems = if ($review) {
        Write-Output "Review comment by $($review.user), posted $($review.created_at)"
        @(Test-ReviewComment $review.body $commits)
    } else { @('Review: no review posted yet; post one starting with <!-- review:ai --> (README, Reviews)') }
    $problems | ForEach-Object { Write-Output $_ }
    if ($problems) { $state = 'failure'; $description = "$($problems.Count) problem(s); see the run" } else { $state = 'success'; $description = 'Review posted in the format' }
}

$target = "$env:GITHUB_SERVER_URL/$Repo/actions/runs/$env:GITHUB_RUN_ID"
Invoke-Gh api "repos/$Repo/statuses/$sha" -f "state=$state" -f 'context=review' -f "description=$description" -f "target_url=$target" --silent
Write-Output "Status review: $state, $description"
if ($state -ne 'success') { exit 1 }
