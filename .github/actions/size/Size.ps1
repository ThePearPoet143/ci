# https://pkg.go.dev/cmd/go#hdr-Test_packages
# https://github.com/kubernetes-sigs/prow/blob/main/pkg/plugins/size/size.go
$IgnoredPaths = @(
    'package-lock.json', 'pnpm-lock.yaml', 'yarn.lock', '*.lock', 'Cargo.lock', 'go.sum',
    'dist/**', 'build/**', 'vendor/**', 'node_modules/**', '**/*.min.js', '**/*.generated.*',
    'changes/**'
)
$TestPaths = @('**/*.test.*', '**/*_test.go', '**/*.spec.*', '**/*.Tests.ps1', '**/__tests__/**', '**/test/**', '**/tests/**')

function ConvertTo-PathRegex([string]$Glob) {
    $re = [regex]::Escape($Glob) -replace '\\\*\\\*/', '(.*/)?' -replace '\\\*\\\*', '.*' -replace '\\\*', '[^/]*' -replace '\\\?', '[^/]'
    if ($Glob -notmatch '/') { $re = "(.*/)?$re" }
    "^$re$"
}

function Test-PathMatch([string]$Path, [string[]]$Globs) {
    foreach ($glob in $Globs) { if ($Path -match (ConvertTo-PathRegex $glob)) { return $true } }
    $false
}

function Get-EffectiveLine([string[]]$Numstat, [string[]]$ExtraIgnored = @()) {
    $files = foreach ($line in $Numstat) {
        $added, $removed, $path = $line -split "`t", 3
        if ($added -eq '-' -or -not $path) { continue }
        if (Test-PathMatch $path ($IgnoredPaths + $ExtraIgnored)) { continue }
        [pscustomobject]@{ Path = $path; Lines = [int]$added + [int]$removed; Test = Test-PathMatch $path $TestPaths }
    }
    $files = @($files)
    $counted = if (@($files | Where-Object { -not $_.Test }).Count -gt 0) { $files | Where-Object { -not $_.Test } } else { $files }
    [int](($counted | Measure-Object Lines -Sum).Sum)
}

function Get-SizeLabel([int]$Lines) {
    if ($Lines -ge 1000) { return 'size:XXL' }
    if ($Lines -ge 500) { return 'size:XL' }
    if ($Lines -ge 100) { return 'size:L' }
    if ($Lines -ge 30) { return 'size:M' }
    if ($Lines -ge 10) { return 'size:S' }
    'size:XS'
}

function Get-SizeVerdict([string]$Label, [bool]$Exempt, [switch]$Release) {
    if ($Release) {
        return [pscustomobject]@{ Pass = $true; ReviewAi = $false; Message = "$Label, a release: its changes were sized and reviewed in dev." }
    }
    $big = $Label -in 'size:XL', 'size:XXL'
    [pscustomobject]@{
        Pass     = (-not $big) -or $Exempt
        ReviewAi = $Label -notin 'size:XS', 'size:S'
        Message  = if ($big -and -not $Exempt) {
            "$Label is over 500 changed lines: split it, or label it size-exempt and say why in the description."
        } elseif ($big) { "$Label, labelled size-exempt." } else { "$Label." }
    }
}