BeforeAll {
    . "$PSScriptRoot\Review.ps1"
    $script:robot = [char]::ConvertFromUtf32(0x1F916)
    function Get-SampleReview([string]$Count = '**AI review: 2 findings, both fixed.** Review of abc1234.', [string[]]$Rows, [string]$Last = "$script:robot Claude Opus 5.5") {
        if (-not $PSBoundParameters.ContainsKey('Rows')) {
            $Rows = @(
                '| 1 | A failed git passed | Fixed in abc1234 | Test "fails when git fails" |'
                '| 2 | Merge commits fail | By design | Merge messages name their issue |'
            )
        }
        (@('<!-- review:ai -->', $Count, '', '| # | Finding | Verdict | Evidence |', '| - | ------- | ------- | -------- |') + $Rows + @('', $Last)) -join "`n"
    }
    $script:commits = @('abc1234def5678', '9999999aaaa')
}

Describe 'Test-ReviewComment' {
    It 'passes a review in the format' {
        Test-ReviewComment (Get-SampleReview) $script:commits | Should -BeNullOrEmpty
    }
    It 'fails a review with no count line' {
        Test-ReviewComment (Get-SampleReview -Count 'Some notes.') $script:commits | Should -Match 'count'
    }
    It 'fails when the count doesn''t match the rows' {
        Test-ReviewComment (Get-SampleReview -Count '**AI review: 3 findings, all fixed.**') $script:commits | Should -Match '3 findings.*2 rows'
    }
    It 'fails a verdict outside the list' {
        $rows = @('| 1 | Something | Maybe later | none |')
        Test-ReviewComment (Get-SampleReview -Count '**AI review: 1 finding.**' -Rows $rows) $script:commits | Should -Match 'Maybe later'
    }
    It 'fails a Fixed in that names a commit not on the PR' {
        $rows = @('| 1 | Something | Fixed in 1234567 | test |')
        Test-ReviewComment (Get-SampleReview -Count '**AI review: 1 finding, fixed.**' -Rows $rows) $script:commits | Should -Match '1234567'
    }
    It 'reads a pipe written as \| inside a cell' {
        $rows = @('| 1 | A `#` line in `run: \|` is flagged | Noted | README says so |')
        Test-ReviewComment (Get-SampleReview -Count '**AI review: 1 finding, noted.**' -Rows $rows) $script:commits | Should -BeNullOrEmpty
    }
    It 'fails a review over 250 words' {
        $rows = @("| 1 | $((1..260 | ForEach-Object { "w$_" }) -join ' ') | Noted | x |")
        Test-ReviewComment (Get-SampleReview -Count '**AI review: 1 finding, noted.**' -Rows $rows) $script:commits | Should -Match '250'
    }
    It 'fails a review without the model line last' {
        Test-ReviewComment (Get-SampleReview -Last 'Thanks') $script:commits | Should -Match 'Last line'
    }
    It 'passes a review with no findings' {
        Test-ReviewComment (Get-SampleReview -Count '**AI review: 0 findings.** Nothing real.' -Rows @()) $script:commits | Should -BeNullOrEmpty
    }
}

Describe 'Find-ReviewComment' {
    It 'takes the newest comment that starts with the marker' {
        $comments = @(
            [pscustomobject]@{ body = "<!-- review:ai -->`nold"; updated_at = '2026-11-15T10:00:00Z'; user = 'pearpoet-agents[bot]'; association = 'NONE' }
            [pscustomobject]@{ body = 'LGTM'; updated_at = '2026-11-15T12:00:00Z'; user = 'someone'; association = 'NONE' }
            [pscustomobject]@{ body = "<!-- review:ai -->`nnew"; updated_at = '2026-11-15T11:00:00Z'; user = 'ThePearPoet143'; association = 'OWNER' }
        )
        (Find-ReviewComment $comments).body | Should -Match 'new'
    }
    It 'finds nothing when no comment has the marker' {
        Find-ReviewComment @([pscustomobject]@{ body = 'LGTM'; updated_at = '2026-11-15T12:00:00Z'; user = 'x'; association = 'OWNER' }) | Should -BeNullOrEmpty
    }
    It 'ignores a review from someone who isn''t the owner, a collaborator or the agents'' app' {
        $comments = @(
            [pscustomobject]@{ body = "<!-- review:ai -->`nours"; updated_at = '2026-11-15T10:00:00Z'; user = 'pearpoet-agents[bot]'; association = 'NONE' }
            [pscustomobject]@{ body = "<!-- review:ai -->`nfake"; updated_at = '2026-11-15T11:00:00Z'; user = 'stranger'; association = 'NONE' }
        )
        (Find-ReviewComment $comments).body | Should -Match 'ours'
    }
}

Describe 'Test-ReviewFresh' {
    It 'passes a review posted or edited after the PR''s latest commit' {
        Test-ReviewFresh '2026-11-15T12:00:00Z' '2026-11-15T11:00:00Z' | Should -BeNullOrEmpty
    }
    It 'fails a review older than the latest commit' {
        Test-ReviewFresh '2026-11-15T10:00:00Z' '2026-11-15T11:00:00Z' | Should -Match 'older than'
    }
}

Describe 'Fixed in, by case' {
    It 'names an uppercase commit as not in the format' {
        $rows = @('| 1 | Something | Fixed in ABC1234 | test |')
        Test-ReviewComment (Get-SampleReview -Count '**AI review: 1 finding, fixed.**' -Rows $rows) $script:commits | Should -Match 'verdict'
    }
}

Describe 'Get-ReviewNeed' {
    It 'needs a review when the PR is labelled review:ai' {
        Get-ReviewNeed @('size:L', 'review:ai') 'dev' 0 | Should -BeTrue
    }
    It 'needs a review at size M from the PR''s own lines, before any label arrives' {
        Get-ReviewNeed @() 'dev' 30 | Should -BeTrue
    }
    It 'needs none for a small unlabelled PR, or for a release into main' {
        Get-ReviewNeed @('size:S') 'dev' 12 | Should -BeFalse
        Get-ReviewNeed @('review:ai') 'main' 900 | Should -BeFalse
    }
}
