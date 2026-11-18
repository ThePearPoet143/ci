# https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference
# https://docs.github.com/en/rest/commits/statuses#list-commit-statuses-for-a-reference

$ReportMarker = '<!-- ci-checks -->'
$ReportName = 'report'
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

function Format-CheckReport($Rows, [string]$Sha) {
    $failed = @($Rows | Where-Object Mark -EQ $Fail)
    $running = @($Rows | Where-Object Mark -EQ $Wait)
    $headline = if ($failed) {
        "**$($failed.Count) check$(if ($failed.Count -gt 1) { 's' }) failed: $(($failed | ForEach-Object { $_.Name }) -join ', ')**"
    } elseif ($running) { "**No failures so far**" } else { "**All $(@($Rows).Count) checks pass**" }
    if ($running) { $headline += ", $($running.Count) still running" }
    $lines = @($ReportMarker, '### Checks', '', "$headline at ``$Sha``.", '', '| | Check |', '| --- | --- |')
    $lines += @($Rows | Sort-Object { $_.Mark -ne $Fail }, Name | ForEach-Object { "| $($_.Mark) | [$($_.Name)]($($_.Link)) |" })
    $lines += '', '<sub>Updated as each check finishes. Each name links to its run.</sub>'
    $lines -join "`n"
}

function Get-ReportCommentId($Comments) {
    ($Comments | Where-Object { ([string]$_.body).StartsWith($ReportMarker) } | Select-Object -First 1).id
}
