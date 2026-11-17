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
if ($env:GITHUB_EVENT_NAME -eq 'pull_request' -and $pull.head.repo.full_name -ne $Repo) {
    Write-Output "A pull request from a fork can't set a status; the review status is set when the owner or the agents comment."
    exit 0
}
$labels = @($pull.labels | ForEach-Object { $_.name })
$sha = $pull.head.sha
$numstat = @(Invoke-Gh api "repos/$Repo/pulls/$Pr/files" --paginate --jq '.[] | [.additions, .deletions, .filename] | @tsv')
$lines = Get-EffectiveLine $numstat
Write-Output "Read PR #${Pr}: base $($pull.base.ref), head $sha, $lines effective changed lines, labels: $($labels -join ', ')"

if (-not (Get-ReviewNeed $labels $pull.base.ref $lines)) {
    $state = 'success'; $description = 'No review needed'
} else {
    $commits = @(Invoke-Gh api "repos/$Repo/pulls/$Pr/commits" --paginate --jq '.[].sha')
    $headDate = Invoke-Gh api "repos/$Repo/commits/$sha" --jq '.commit.committer.date'
    $comments = @(Invoke-Gh api "repos/$Repo/issues/$Pr/comments" --paginate --jq '.[] | {body, updated_at, user: .user.login, association: .author_association}' | ForEach-Object { $_ | ConvertFrom-Json })
    Write-Output "Read $($commits.Count) commits (latest at $headDate) and $($comments.Count) comments"
    $review = Find-ReviewComment $comments
    $problems = if ($review) {
        Write-Output "Review comment by $($review.user) ($($review.association)), last changed $($review.updated_at)"
        @(Test-ReviewFresh $review.updated_at $headDate) + @(Test-ReviewComment $review.body $commits)
    } else { @('Review: no review posted yet by the owner, a collaborator or the agents; post one starting with <!-- review:ai --> (README, Reviews)') }
    $problems = @($problems | Where-Object { $_ })
    $problems | ForEach-Object { Write-Output $_ }
    if ($problems) { $state = 'failure'; $description = "$($problems.Count) problem(s); see the run" } else { $state = 'success'; $description = 'Review posted in the format' }
}

$target = "$env:GITHUB_SERVER_URL/$Repo/actions/runs/$env:GITHUB_RUN_ID"
Invoke-Gh api "repos/$Repo/statuses/$sha" -f "state=$state" -f 'context=review' -f "description=$description" -f "target_url=$target" --silent
Write-Output "Status review: $state, $description"
