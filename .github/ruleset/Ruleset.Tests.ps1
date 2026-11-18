BeforeAll {
    . "$PSScriptRoot\Ruleset.ps1"
    $script:expected = Read-Ruleset
    function Get-SampleRule([int]$Approvals = 1, [bool]$Owners = $true, [string[]]$Checks) {
        if (-not $PSBoundParameters.ContainsKey('Checks')) { $Checks = Get-RequiredCheck $script:expected }
        @(
            [pscustomobject]@{ type = 'pull_request'; parameters = [pscustomobject]@{ required_approving_review_count = $Approvals; require_code_owner_review = $Owners } }
            [pscustomobject]@{ type = 'required_status_checks'; parameters = [pscustomobject]@{ required_status_checks = @($Checks | ForEach-Object { [pscustomobject]@{ context = $_ } }) } }
            [pscustomobject]@{ type = 'non_fast_forward' }
            [pscustomobject]@{ type = 'deletion' }
        )
    }
}

Describe 'Read-Ruleset' {
    It 'covers dev and main, and requires every check a PR runs, the review status included' {
        $script:expected.conditions.ref_name.include | Should -Be @('refs/heads/dev', 'refs/heads/main')
        Get-RequiredCheck $script:expected | Should -Contain 'review'
        Get-RequiredCheck $script:expected | Should -Contain 'tests (windows-latest, powershell)'
    }
}

Describe 'Test-BranchRule' {
    It 'passes a branch with every rule in force' {
        Test-BranchRule 'dev' (Get-SampleRule) $script:expected | Should -BeNullOrEmpty
    }
    It 'fails a branch with no rules, as today' {
        (@(Test-BranchRule 'dev' @() $script:expected) -join ' ') | Should -Match 'dev.*no pull request rule'
    }
    It 'fails without an approval or code owner review' {
        Test-BranchRule 'main' (Get-SampleRule -Approvals 0) $script:expected | Should -Match 'approval'
        Test-BranchRule 'main' (Get-SampleRule -Owners $false) $script:expected | Should -Match 'code owner'
    }
    It 'names a required check that is missing' {
        (@(Test-BranchRule 'dev' (Get-SampleRule -Checks @('text', 'size')) $script:expected) -join ' ') | Should -Match 'review'
    }
    It 'reads the strictest pull request rule when two rule sets apply' {
        $weaker = [pscustomobject]@{ type = 'pull_request'; parameters = [pscustomobject]@{ required_approving_review_count = 0; require_code_owner_review = $false } }
        Test-BranchRule 'dev' (@($weaker) + @(Get-SampleRule)) $script:expected | Should -BeNullOrEmpty
    }
    It 'fails when force-pushing or deleting is allowed' {
        $rules = @(Get-SampleRule | Where-Object type -NE 'deletion')
        Test-BranchRule 'dev' $rules $script:expected | Should -Match 'deletion'
    }
}
