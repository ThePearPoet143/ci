BeforeAll {
    . "$PSScriptRoot\TextCheck.ps1"

    function Pr([string]$Problem = 'Nothing checks the machine.', [string]$Change = 'Adds the doctor.',
        [string]$Verification = "- Ran the doctor here: all pass.`n- Not checked: a Mac.", [string]$Extra = '',
        [string]$Last = '🤖 Claude Opus 5.5 · Claude Code') {
        "## Problem`n`n$Problem`n`n## Change`n`n$Change`n`n## Scope`n`nHQ-1.`n`n## Verification`n`n$Verification`n`n$Extra`n`n$Last"
    }
}

Describe 'Test-PrTitle' {
    It 'passes a type, a scope, plain words and the issue key last' {
        Test-PrTitle 'feat(doctor): flag other T3 tasks (SUS-25)' 'SUS' | Should -BeNullOrEmpty
    }
    It 'passes without a scope, and with a breaking-change mark' {
        Test-PrTitle 'fix: a slow check no longer blocks (SUS-3)' 'SUS' | Should -BeNullOrEmpty
        Test-PrTitle 'feat(doctor)!: checks run under PowerShell 7 (SUS-30)' 'SUS' | Should -BeNullOrEmpty
    }
    It 'fails an unknown type' {
        Test-PrTitle 'feature(doctor): flag other T3 tasks (SUS-25)' 'SUS' | Should -Match 'type'
    }
    It 'fails a missing or wrong issue key' {
        Test-PrTitle 'feat(doctor): flag other T3 tasks' 'SUS' | Should -Match 'SUS-'
        Test-PrTitle 'feat(doctor): flag other T3 tasks (GDS-25)' 'SUS' | Should -Match 'SUS-'
    }
    It 'fails a title over 72 characters' {
        Test-PrTitle ('feat(doctor): ' + ('x' * 60) + ' (SUS-25)') 'SUS' | Should -Match '72'
    }
}

Describe 'Get-WordCount' {
    It 'counts words and numbers, not marks or symbols' {
        Get-WordCount 'The doctor shows ✓ on 2 PCs — fine.' | Should -Be 7
    }
}

Describe 'Release titles' {
    It 'requires a PR into main to be titled as a release' {
        Test-PrTitle 'feat(doctor): flag other T3 tasks (HQ-25)' 'HQ' 'main' | Should -Match 'chore\(release\)'
        Test-PrTitle 'chore(release): v0.5, more (HQ-25)' 'HQ' 'main' | Should -Match 'vX.Y.Z'
        Test-PrTitle 'chore(release): v0.5.0, more checks (HQ-25)' 'HQ' 'main' | Should -BeNullOrEmpty
    }
    It 'leaves a PR into dev free of it' {
        Test-PrTitle 'feat(doctor): flag other T3 tasks (HQ-25)' 'HQ' 'dev' | Should -BeNullOrEmpty
    }
}

Describe 'Test-PrBody' {
    It 'passes Problem, Change, Scope and Verification, and the model and tool line' {
        Test-PrBody 'chore' (Pr) | Should -BeNullOrEmpty
    }
    It 'fails without each of the four sections' {
        foreach ($name in 'Problem', 'Change', 'Scope', 'Verification') {
            $body = (Pr) -replace "## $name`n`n[^#]*", ''
            (Test-PrBody 'chore' $body) -join ' ' | Should -Match $name
        }
    }
    It 'fails when Problem and Change are over 120 words together' {
        Test-PrBody 'chore' (Pr -Problem (('word ' * 61).Trim()) -Change (('word ' * 60).Trim())) | Should -Match '121 words'
    }
    It 'fails a Verification that doesn''t say what couldn''t be checked' {
        Test-PrBody 'chore' (Pr -Verification '- Ran the doctor here: all pass.') | Should -Match 'Not checked'
        Test-PrBody 'chore' (Pr -Verification "- Ran it.`n- Not checked: nothing; it ran on every OS.") | Should -BeNullOrEmpty
    }
    It 'fails a fix whose Verification doesn''t name the Red test' {
        Test-PrBody 'fix' (Pr) | Should -Match 'Red'
        Test-PrBody 'fix' (Pr -Verification "- Red: 1 failed first.`n- Green: 3 passed.`n- Not checked: a Mac.") | Should -BeNullOrEmpty
    }
    It 'fails when the last line doesn''t name the model, its version and the tool' {
        Test-PrBody 'chore' (Pr -Last 'Written with an agent.') | Should -Match '🤖'
        Test-PrBody 'chore' (Pr -Last '🤖 Claude · Claude Code') | Should -Match 'version'
        Test-PrBody 'chore' (Pr -Last '🤖 Claude Opus 5.5') | Should -Match 'tool'
    }
}

Describe 'The PR template' {
    It 'fails the text check until it is filled in' {
        $template = [IO.File]::ReadAllText("$PSScriptRoot/../../pull_request_template.md")
        $problems = (@(Test-PrBody 'chore' $template) -join ' ')
        $problems | Should -Match 'Not checked'
        $problems | Should -Match 'Last line'
    }
    It 'fails an empty "Not checked:" line' {
        Test-PrBody 'chore' (Pr -Verification "- Ran it.`n- Not checked:") | Should -Match 'Not checked'
    }
}

Describe 'Empty sections and case' {
    It 'fails an empty Problem or Verification' {
        (@(Test-PrBody 'chore' (Pr -Problem '')) -join ' ') | Should -Match 'Problem'
        (@(Test-PrBody 'chore' (Pr -Verification '')) -join ' ') | Should -Match 'Verification'
    }
    It 'fails an uppercase type and a lowercase key' {
        Test-PrTitle 'FEAT(doctor): flag things (HQ-12)' 'HQ' | Should -Match 'type'
        Test-PrTitle 'feat(doctor): flag things (hq-12)' 'HQ' | Should -Match 'issue key'
    }
}

Describe 'Test-IssueText' {
    It 'passes a short title and a body with a done-when' {
        Test-IssueText 'Doctor: flag other T3 tasks' "The doctor flags them.`n`nDone when: both PCs show ✓." | Should -BeNullOrEmpty
    }
    It 'fails a title over 60 characters, a body over 80 words, and no done-when' {
        $problems = Test-IssueText ('x' * 61) (('word ' * 81).Trim())
        $problems -join ' | ' | Should -Match '60'
        $problems -join ' | ' | Should -Match '81 words'
        $problems -join ' | ' | Should -Match 'Done when'
    }
}
