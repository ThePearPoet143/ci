BeforeAll {
    . "$PSScriptRoot\Ruleset.ps1"
    function Get-SampleRule([int]$Approvals = 0, [bool]$Owners = $true, [string[]]$Checks) {
        @(
            [pscustomobject]@{ type = 'pull_request'; parameters = [pscustomobject]@{ required_approving_review_count = $Approvals; require_code_owner_review = $Owners } }
            [pscustomobject]@{ type = 'required_status_checks'; parameters = [pscustomobject]@{ required_status_checks = @($Checks | ForEach-Object { [pscustomobject]@{ context = $_ } }) } }
            [pscustomobject]@{ type = 'non_fast_forward' }
            [pscustomobject]@{ type = 'deletion' }
        )
    }
}

Describe 'Read-Ruleset' {
    It 'gives each repo a rule set for dev and one for main' -ForEach @(@{ Repo = 'ThePearPoet143/ci' }, @{ Repo = 'ThePearPoet143/ci-sandbox' }) {
        $sets = @(Read-Ruleset $Repo)
        (Get-BranchRuleset $sets 'dev').name | Should -Not -BeNullOrEmpty
        (Get-BranchRuleset $sets 'main').name | Should -Not -BeNullOrEmpty
    }
    It 'needs no approval on dev but the code owner''s, and an approval on main' -ForEach @(@{ Repo = 'ThePearPoet143/ci' }, @{ Repo = 'ThePearPoet143/ci-sandbox' }) {
        $sets = @(Read-Ruleset $Repo)
        $dev = (Get-BranchRuleset $sets 'dev').rules | Where-Object type -EQ 'pull_request'
        $main = (Get-BranchRuleset $sets 'main').rules | Where-Object type -EQ 'pull_request'
        $dev.parameters.required_approving_review_count | Should -Be 0
        $dev.parameters.require_code_owner_review | Should -BeTrue
        $main.parameters.required_approving_review_count | Should -Be 1
        $main.parameters.require_code_owner_review | Should -BeTrue
    }
    It 'requires the checks each repo runs, by the names GitHub shows' {
        Get-RequiredCheck (Get-BranchRuleset @(Read-Ruleset 'ThePearPoet143/ci') 'dev') | Should -Contain 'tests (windows-latest, powershell)'
        Get-RequiredCheck (Get-BranchRuleset @(Read-Ruleset 'ThePearPoet143/ci-sandbox') 'dev') | Should -Contain 'core / text'
    }
    It 'fails a repo with no rule set file' {
        { Read-Ruleset 'ThePearPoet143/nothing' } | Should -Throw '*nothing.json*'
    }
}

Describe 'Test-BranchRule' {
    BeforeAll { $script:sets = @(Read-Ruleset 'ThePearPoet143/ci'); $script:checks = Get-RequiredCheck (Get-BranchRuleset $script:sets 'dev') }
    It 'passes dev with no approval but code owners, and main with one approval' {
        Test-BranchRule 'dev' (Get-SampleRule -Checks $script:checks) $script:sets | Should -BeNullOrEmpty
        Test-BranchRule 'main' (Get-SampleRule -Approvals 1 -Checks $script:checks) $script:sets | Should -BeNullOrEmpty
    }
    It 'fails main without its approval, and either branch without code owner review' {
        Test-BranchRule 'main' (Get-SampleRule -Checks $script:checks) $script:sets | Should -Match 'approval'
        Test-BranchRule 'dev' (Get-SampleRule -Owners $false -Checks $script:checks) $script:sets | Should -Match 'code owner'
    }
    It 'fails a branch with no rules' {
        (@(Test-BranchRule 'dev' @() $script:sets) -join ' ') | Should -Match 'dev.*no pull request rule'
    }
    It 'names a required check that is missing' {
        (@(Test-BranchRule 'dev' (Get-SampleRule -Checks @('text', 'size')) $script:sets) -join ' ') | Should -Match 'review'
    }
    It 'reads the strictest pull request rule when two rule sets apply' {
        $weaker = [pscustomobject]@{ type = 'pull_request'; parameters = [pscustomobject]@{ required_approving_review_count = 0; require_code_owner_review = $false } }
        Test-BranchRule 'main' (@($weaker) + @(Get-SampleRule -Approvals 1 -Checks $script:checks)) $script:sets | Should -BeNullOrEmpty
    }
    It 'fails when force-pushing or deleting is allowed' {
        $rules = @(Get-SampleRule -Checks $script:checks | Where-Object type -NE 'deletion')
        Test-BranchRule 'dev' $rules $script:sets | Should -Match 'deletion'
    }
}

Describe 'Get-RulesetOrder' {
    It 'creates the missing rule sets before it changes existing ones, so main is never left without rules' {
        $sets = @(Read-Ruleset 'ThePearPoet143/ci')
        $order = @(Get-RulesetOrder $sets @([pscustomobject]@{ name = 'ci'; id = 7 }))
        $order[0].Ruleset.name | Should -Be 'ci main'
        $order[0].Id | Should -BeNullOrEmpty
        $order[1].Ruleset.name | Should -Be 'ci'
        $order[1].Id | Should -Be 7
    }
}

Describe 'Test-BranchRule with nothing expected' {
    It 'fails a branch the repo''s file has no rule set for' {
        { Test-BranchRule 'release' @() @(Read-Ruleset 'ThePearPoet143/ci') } | Should -Throw '*release*'
    }
}

Describe 'Read-Ruleset owners' {
    It 'refuses a repo of another owner, even with a file of the same name' {
        { Read-Ruleset 'someone-else/ci' } | Should -Throw '*ThePearPoet143*'
    }
}

Describe 'Test-RulesetEnvironment' {
    BeforeAll {
        function Get-SampleEnvironment([string[]]$Logins = @('ThePearPoet143'), [bool]$SelfReview = $false, [bool]$Custom = $true) {
            [pscustomobject]@{
                name = 'rulesets'
                protection_rules = @([pscustomobject]@{ type = 'required_reviewers'; prevent_self_review = $SelfReview; reviewers = @($Logins | ForEach-Object { [pscustomobject]@{ type = 'User'; reviewer = [pscustomobject]@{ login = $_ } } }) })
                deployment_branch_policy = [pscustomobject]@{ protected_branches = $false; custom_branch_policies = $Custom }
            }
        }
        $script:dev = @([pscustomobject]@{ name = 'dev'; type = 'branch' })
        $script:allowed = @(Read-RulesetReviewer)
    }
    It 'passes reviewers from the list, self-review off, and only dev' {
        Test-RulesetEnvironment (Get-SampleEnvironment) $script:dev $script:allowed | Should -BeNullOrEmpty
        Test-RulesetEnvironment (Get-SampleEnvironment -Logins @()) $script:dev @('ThePearPoet143', 'someone') | Should -Match 'no required reviewer'
    }
    It 'fails a missing environment' {
        Test-RulesetEnvironment $null @() $script:allowed | Should -Match 'no rulesets environment'
    }
    It 'fails a reviewer who isn''t on the list' {
        Test-RulesetEnvironment (Get-SampleEnvironment -Logins @('ThePearPoet143', 'stranger')) $script:dev $script:allowed | Should -Match 'stranger'
    }
    It 'fails with self-review prevented, since the owner approves their own run' {
        Test-RulesetEnvironment (Get-SampleEnvironment -SelfReview $true) $script:dev $script:allowed | Should -Match 'self-review'
    }
    It 'fails unless only dev may use it' {
        Test-RulesetEnvironment (Get-SampleEnvironment -Custom $false) $script:dev $script:allowed | Should -Match 'dev'
        Test-RulesetEnvironment (Get-SampleEnvironment) @($script:dev + [pscustomobject]@{ name = 'feature/*'; type = 'branch' }) $script:allowed | Should -Match 'feature'
        $noPolicy = Get-SampleEnvironment; $noPolicy.deployment_branch_policy = $null
        Test-RulesetEnvironment $noPolicy @() $script:allowed | Should -Match 'any branch'
    }
}
