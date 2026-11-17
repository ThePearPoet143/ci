BeforeAll {
    . "$PSScriptRoot\Audit.ps1"
}

Describe 'Get-IssueBody' {
    It 'leaves out the Agent notes, as Linear stores them or as they are written' {
        Get-IssueBody "Why.`n`nDone when: x.`n`n>>> Agent notes`n`nlots of notes`n`n>>>" | Should -Be "Why.`n`nDone when: x."
        Get-IssueBody "Why.`n`nDone when: x.`n`n+++ Agent notes`n`nnotes`n`n+++" | Should -Be "Why.`n`nDone when: x."
        Get-IssueBody 'Why. Done when: x.' | Should -Be 'Why. Done when: x.'
    }
    It 'keeps text after the Agent notes section' {
        Get-IssueBody "Why.`n`n>>> Agent notes`n`nnotes`n`n>>>`n`nDone when: x." | Should -Match 'Done when: x\.'
        Get-IssueBody "Why.`n`n>>> Agent notes`n`nnotes`n`n>>>`n`nDone when: x." | Should -Not -Match 'notes'
    }
}

Describe 'Format-AuditRead' {
    It 'names each issue by its key only, since the logs are public' {
        $issue = [pscustomobject]@{ identifier = 'HQ-3'; title = 'A private plan'; updatedAt = '2026-11-15T04:51:16Z' }
        $line = Format-AuditRead $issue
        $line | Should -Match '^Read HQ-3'
        $line | Should -Not -Match 'private plan'
    }
}

Describe 'IssueQuery' {
    It 'leaves out closed issues: completed, canceled and duplicate' {
        foreach ($type in 'completed', 'canceled', 'duplicate') { $IssueQuery | Should -Match "`"$type`"" }
    }
}

Describe 'Get-AuditSkip' {
    It 'skips a pull request run with no key, as a fork''s gets none' {
        Get-AuditSkip 'pull_request' '' | Should -Match 'fork'
    }
    It 'never skips a scheduled run' {
        Get-AuditSkip 'schedule' '' | Should -BeNullOrEmpty
        Get-AuditSkip 'pull_request' 'lin_api_x' | Should -BeNullOrEmpty
    }
}

Describe 'Find-IssueAuditProblem' {
    It 'passes an issue that meets the rules' {
        $issue = [pscustomobject]@{ identifier = 'HQ-1'; title = 'Short'; description = "Why.`n`nDone when: it works." }
        Find-IssueAuditProblem $issue | Should -BeNullOrEmpty
    }
    It 'names the issue and each rule it breaks' {
        $long = (1..90 | ForEach-Object { "word$_" }) -join ' '
        $issue = [pscustomobject]@{ identifier = 'HQ-99'; title = 'x' * 61; description = $long }
        $problems = @(Find-IssueAuditProblem $issue)
        $problems.Count | Should -Be 3
        $problems | ForEach-Object { $_ | Should -Match '^HQ-99: ' }
    }
    It 'treats an issue with no description as missing its Done when' {
        $issue = [pscustomobject]@{ identifier = 'HQ-5'; title = 'Short'; description = $null }
        Find-IssueAuditProblem $issue | Should -Match 'Done when'
    }
}

Describe 'Get-AuditReadProblem' {
    It 'fails when the key can''t see the team' {
        Get-AuditReadProblem 'HQ' $false 0 | Should -Match 'team HQ'
    }
    It 'fails when it read no issues, so an audit can''t pass on nothing' {
        Get-AuditReadProblem 'HQ' $true 0 | Should -Match 'no open issues'
    }
    It 'passes when it read issues' {
        Get-AuditReadProblem 'HQ' $true 15 | Should -BeNullOrEmpty
    }
}

Describe 'ConvertFrom-IssuePage' {
    It 'reads Linear''s issues, whether the next page exists, and its cursor' {
        $json = '{"data":{"issues":{"nodes":[{"identifier":"HQ-1","title":"A","description":"B","updatedAt":"2026-11-15T00:00:00Z"}],"pageInfo":{"hasNextPage":true,"endCursor":"abc"}}}}'
        $page = ConvertFrom-IssuePage $json
        @($page.Issues).Count | Should -Be 1
        $page.Issues[0].identifier | Should -Be 'HQ-1'
        $page.HasNextPage | Should -BeTrue
        $page.EndCursor | Should -Be 'abc'
    }
    It 'fails on a GraphQL error instead of reading it as no issues' {
        { ConvertFrom-IssuePage '{"errors":[{"message":"Authentication required"}]}' } | Should -Throw '*Authentication required*'
    }
}
