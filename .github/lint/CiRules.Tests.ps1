BeforeAll {
    Import-Module PSScriptAnalyzer -RequiredVersion (Import-PowerShellDataFile (Join-Path $PSScriptRoot '../tools/tools.psd1')).PSScriptAnalyzer
    $script:rules = Join-Path $PSScriptRoot 'CiRules.psm1'
}

Describe 'CiRules.psm1' {
    It 'reports a trap through PSScriptAnalyzer, once, with the default rules still on' {
        $path = Join-Path ([IO.Path]::GetTempPath()) "ci-lint-$([guid]::NewGuid().ToString('N')).ps1"
        Set-Content $path "function Get-Thing { param(`$Unused) gh api /repos/x/y }"
        try {
            $findings = @(Invoke-ScriptAnalyzer -Path $path -CustomRulePath $script:rules -IncludeDefaultRules)
        } finally {
            Remove-Item $path
        }
        @($findings | Where-Object RuleName -EQ 'GhApiLeadingSlash').Count | Should -Be 1
        $findings.RuleName | Should -Contain 'PSReviewUnusedParameter'
    }
}
