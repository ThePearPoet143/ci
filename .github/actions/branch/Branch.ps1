# The branch and commit checks (SUS-29). Pull requests go into dev; main holds only releases, dev merged into main.
# Commits start with their issue key, so Linear links each one.

function Test-IsRelease([string]$Base, [string]$Head, [string]$HeadRepo, [string]$Repo) {
    $Base -ceq 'main' -and $Head -ceq 'dev' -and $HeadRepo -eq $Repo
}

function Test-PrTarget([string]$Base, [string]$Head, [string]$HeadRepo, [string]$Repo) {
    if ($Base -ceq 'dev' -or (Test-IsRelease $Base $Head $HeadRepo $Repo)) { return }
    if ($Base -cne 'main') { "Target: pull requests go into dev, not $Base"; return }
    if ($Head -ceq 'dev') { "Target: a release comes from this repo's dev, not $HeadRepo's" }
    else { "Target: a pull request into main must be a release from dev; target dev instead (this one is from $Head)" }
}

# GitHub writes "Merge pull request #n from …" when it merges; those carry the PR's own key in its title.
function Test-CommitSubject([string]$Subject, [string]$IssuePrefix) {
    if ($Subject -cmatch '^Merge pull request #\d+ from ') { return }
    if ($Subject -cnotmatch "^$IssuePrefix-\d+: ") { "Commit: start with the issue key, e.g. '$IssuePrefix-123: …': ""$Subject""" }
}

# A warning, not a failure: Linear moves an issue to Done only when a pull request names it.
function Test-ReleaseIssueList([string]$Body, [string]$IssuePrefix) {
    if ($Body -notmatch "\b$IssuePrefix-\d+\b") { "Release: name the issues it releases ($IssuePrefix-123), so Linear can follow them" }
}