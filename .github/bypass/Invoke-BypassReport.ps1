# https://docs.github.com/en/graphql/reference/objects#pullrequest
# https://docs.github.com/en/graphql/reference/objects#statuscheckrollup
param([datetime]$Since = (Get-Date).ToUniversalTime().AddHours(-25), [string]$Owner = 'ThePearPoet143')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Bypass.ps1"

$query = 'query($o:String!,$n:String!){repository(owner:$o,name:$n){pullRequests(states:MERGED,first:50,orderBy:{field:UPDATED_AT,direction:DESC}){nodes{number url mergedAt baseRefName reviews(states:APPROVED){totalCount} commits(last:1){nodes{commit{statusCheckRollup{contexts(first:100){nodes{__typename ... on CheckRun{name conclusion completedAt} ... on StatusContext{context state createdAt}}}}}}}}}}}'
$findings = @()
foreach ($file in Get-ChildItem "$PSScriptRoot/../ruleset/repos" -Filter *.json) {
    $owner = $Owner
    $name = $file.BaseName
    $repo = "$owner/$name"
    $out = & gh api graphql -f "query=$query" -f "o=$owner" -f "n=$name"
    if ($LASTEXITCODE) { throw "gh api graphql failed for $repo" }
    $data = ($out -join "`n") | ConvertFrom-Json
    foreach ($node in $data.data.repository.pullRequests.nodes) {
        if ([datetime]$node.mergedAt -lt $Since) { continue }
        $contexts = $node.commits.nodes[0].commit.statusCheckRollup.contexts.nodes
        $pr = [pscustomobject]@{
            number      = $node.number
            baseRefName = $node.baseRefName
            approvals   = $node.reviews.totalCount
            checks      = @($contexts | ForEach-Object { if ($_.__typename -eq 'CheckRun') { @{ name = $_.name; state = $_.conclusion; at = $_.completedAt } } else { @{ name = $_.context; state = $_.state; at = $_.createdAt } } })
        }
        $reasons = @(Get-BypassReason $pr)
        if ($reasons) { $findings += [pscustomobject]@{ Repo = $repo; Number = $node.number; Url = $node.url; Reasons = $reasons } }
    }
}
Format-BypassReport $findings
if ($findings) { exit 1 }
