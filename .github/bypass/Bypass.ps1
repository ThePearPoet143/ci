# https://docs.github.com/en/graphql/reference/enums#checkconclusionstate
# https://docs.github.com/en/graphql/reference/enums#statusstate
$RedStates = 'FAILURE', 'ERROR', 'CANCELLED', 'TIMED_OUT', 'ACTION_REQUIRED', 'STARTUP_FAILURE'

function Get-BypassReason($Pr) {
    $latest = @($Pr.checks | Group-Object { $_.name } | ForEach-Object { $_.Group | Sort-Object { [string]$_.at } | Select-Object -Last 1 })
    $red = @($Pr.checks | Where-Object { $latest -contains $_ -and $RedStates -contains $_.state } | ForEach-Object { $_.name })
    if ($red) { "merged with red checks: $($red -join ', ')" }
    if ($Pr.baseRefName -eq 'main' -and $Pr.approvals -lt 1) { 'merged into main with no approval' }
}

function Format-BypassReport($Findings) {
    if (-not @($Findings).Count) { return 'No bypasses.' }
    "$(@($Findings).Count) pull request(s) merged past the rules. Each should be the owner's own rule change or release:"
    foreach ($f in $Findings) { "- $($f.Repo)#$($f.Number) $($f.Url): $($f.Reasons -join '; ')" }
}
