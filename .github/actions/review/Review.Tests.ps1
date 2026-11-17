BeforeAll {
    . "$PSScriptRoot\Review.ps1"
    $script:robot = [char]::ConvertFromUtf32(0x1F916)
    function New-Review([string]$Count = '**AI review: 2 findings, both fixed.** Review of abc1234.', [string[]]$Rows, [string]$Last = "$script:robot Claude Opus 5.5") {
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
        Test-ReviewComment (New-Review) $script:commits | Should -BeNullOrEmpty
    }
    It 'fails a review with no count line' {
        Test-ReviewComment (New-Review -Count 'Some notes.') $script:commits | Should -Match 'count'
    }
    It 'fails when the count doesn''t match the rows' {
        Test-ReviewComment (New-Review -Count '**AI review: 3 findings, all fixed.**') $script:commits | Should -Match '3 findings.*2 rows'
    }
    It 'fails a verdict outside the list' {
        $rows = @('| 1 | Something | Maybe later | none |')
        Test-ReviewComment (New-Review -Count '**AI review: 1 finding.**' -Rows $rows) $script:commits | Should -Match 'Maybe later'
    }
    It 'fails a Fixed in that names a commit not on the PR' {
        $rows = @('| 1 | Something | Fixed in 1234567 | test |')
        Test-ReviewComment (New-Review -Count '**AI review: 1 finding, fixed.**' -Rows $rows) $script:commits | Should -Match '1234567'
    }
    It 'reads a pipe written as \| inside a cell' {
        $rows = @('| 1 | A `#` line in `run: \|` is flagged | Noted | README says so |')
        Test-ReviewComment (New-Review -Count '**AI review: 1 finding, noted.**' -Rows $rows) $script:commits | Should -BeNullOrEmpty
    }
    It 'fails a review over 250 words' {
        $rows = @("| 1 | $((1..260 | ForEach-Object { "w$_" }) -join ' ') | Noted | x |")
        Test-ReviewComment (New-Review -Count '**AI review: 1 finding, noted.**' -Rows $rows) $script:commits | Should -Match '250'
    }
    It 'fails a review without the model line last' {
        Test-ReviewComment (New-Review -Last 'Thanks') $script:commits | Should -Match 'Last line'
    }
    It 'passes a review with no findings' {
        Test-ReviewComment (New-Review -Count '**AI review: 0 findings.** Nothing real.' -Rows @()) $script:commits | Should -BeNullOrEmpty
    }
}

Describe 'Find-ReviewComment' {
    It 'takes the newest comment that starts with the marker' {
        $comments = @(
            [pscustomobject]@{ body = "<!-- review:ai -->`nold"; created_at = '2026-11-15T10:00:00Z' }
            [pscustomobject]@{ body = 'LGTM'; created_at = '2026-11-15T12:00:00Z' }
            [pscustomobject]@{ body = "<!-- review:ai -->`nnew"; created_at = '2026-11-15T11:00:00Z' }
        )
        (Find-ReviewComment $comments).body | Should -Match 'new'
    }
    It 'finds nothing when no comment has the marker' {
        Find-ReviewComment @([pscustomobject]@{ body = 'LGTM'; created_at = '2026-11-15T12:00:00Z' }) | Should -BeNullOrEmpty
    }
}

Describe 'Get-ReviewNeed' {
    It 'needs a review when the PR is labelled review:ai' {
        Get-ReviewNeed @('size:L', 'review:ai') 'dev' | Should -BeTrue
    }
    It 'needs none without the label, or for a release into main' {
        Get-ReviewNeed @('size:S') 'dev' | Should -BeFalse
        Get-ReviewNeed @('review:ai') 'main' | Should -BeFalse
    }
}
