# https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference
# https://docs.github.com/en/rest/commits/statuses#list-commit-statuses-for-a-reference

$ReportMarker = '<!-- ci-checks -->'
$ReportName = 'report'
$ReportAuthor = 'github-actions[bot]'
$Pass = [string][char]0x2713
$Fail = [string][char]0x2717
$Skip = [string][char]0x2013
$Wait = [string][char]0x2026

function ConvertTo-ReportRow($CheckRuns, $Statuses) {
    foreach ($run in $CheckRuns | Where-Object { $_.name -ne $ReportName }) {
        $mark = if ($run.status -ne 'completed') { $Wait }
        elseif ($run.conclusion -eq 'success') { $Pass }
        elseif ($run.conclusion -in 'skipped', 'neutral') { $Skip }
        else { $Fail }
        [pscustomobject]@{ Name = $run.name; Mark = $mark; Link = $run.html_url }
    }
    foreach ($group in $Statuses | Group-Object context) {
        $status = $group.Group | Sort-Object { [datetime]$_.created_at } | Select-Object -Last 1
        $mark = switch ($status.state) { 'success' { $Pass } 'pending' { $Wait } default { $Fail } }
        [pscustomobject]@{ Name = $status.context; Mark = $mark; Link = $status.target_url }
    }
}

function ConvertTo-SafeName([string]$Name) {
    [regex]::Replace($Name, '[\\|\[\]()<>@*`_~#!]', { param($m) '&#{0};' -f [int][char]$m.Value })
}

function Format-CheckReport($Rows, [string]$Sha) {
    $failed = @($Rows | Where-Object Mark -EQ $Fail)
    $running = @($Rows | Where-Object Mark -EQ $Wait)
    $passed = @($Rows | Where-Object Mark -EQ $Pass)
    $skipped = @($Rows | Where-Object Mark -EQ $Skip)
    $headline = if ($failed) {
        "**$($failed.Count) check$(if ($failed.Count -gt 1) { 's' }) failed: $(($failed | ForEach-Object { ConvertTo-SafeName $_.Name }) -join ', ')**"
    } elseif ($running) { '**No failures so far**' } else { "**All $($passed.Count) checks pass**" }
    if ($running) { $headline += ", $($running.Count) still running" }
    if ($skipped) { $headline += ", $($skipped.Count) skipped" }
    $lines = @($ReportMarker, '### Checks', '', "$headline at ``$Sha``.", '', '| | Check |', '| --- | --- |')
    $lines += @($Rows | Sort-Object { $_.Mark -ne $Fail }, Name | ForEach-Object { "| $($_.Mark) | [$(ConvertTo-SafeName $_.Name)]($($_.Link)) |" })
    $lines += '', "<sub>Updated when each of ci's workflows finishes, and when a review is posted. Each name links to its run.</sub>"
    $lines -join "`n"
}

function Get-ReportCommentId($Comments) {
    ($Comments | Where-Object { $_.user -eq $ReportAuthor -and ([string]$_.body).StartsWith($ReportMarker) } | Select-Object -First 1).id
}

function Test-ReportTarget($Pull, [string]$Sha, [string]$Repo) {
    $Pull.state -eq 'open' -and $Pull.head.sha -eq $Sha -and $Pull.base.repo.full_name -eq $Repo
}
