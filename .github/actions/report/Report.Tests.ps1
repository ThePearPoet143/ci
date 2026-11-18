BeforeAll {
    . "$PSScriptRoot\Report.ps1"
    function Get-SampleRun([string]$Name, [string]$Status = 'completed', [string]$Conclusion = 'success') {
        [pscustomobject]@{ name = $Name; status = $Status; conclusion = $Conclusion; html_url = "https://example.com/$Name" }
    }
}

Describe 'ConvertTo-ReportRow' {
    It 'marks each check run and status by its result, the repo''s own jobs included' {
        $runs = @((Get-SampleRun 'text'), (Get-SampleRun 'unit tests' -Conclusion 'failure'), (Get-SampleRun 'links' -Conclusion 'skipped'), (Get-SampleRun 'size' -Status 'in_progress' -Conclusion $null))
        $statuses = @([pscustomobject]@{ context = 'review'; state = 'success'; target_url = 'https://example.com/review'; created_at = '2026-11-18T00:00:00Z' })
        $rows = @(ConvertTo-ReportRow $runs $statuses)
        ($rows | Where-Object Name -EQ 'text').Mark | Should -Be '✓'
        ($rows | Where-Object Name -EQ 'unit tests').Mark | Should -Be '✗'
        ($rows | Where-Object Name -EQ 'links').Mark | Should -Be '–'
        ($rows | Where-Object Name -EQ 'size').Mark | Should -Be '…'
        ($rows | Where-Object Name -EQ 'review').Mark | Should -Be '✓'
    }
    It 'reads only the newest status of each name, and leaves out the report itself' {
        $statuses = @(
            [pscustomobject]@{ context = 'review'; state = 'success'; target_url = ''; created_at = '2026-11-18T02:00:00Z' }
            [pscustomobject]@{ context = 'review'; state = 'failure'; target_url = ''; created_at = '2026-11-18T01:00:00Z' }
        )
        $rows = @(ConvertTo-ReportRow @(Get-SampleRun 'report') $statuses)
        $rows.Count | Should -Be 1
        $rows[0].Mark | Should -Be '✓'
    }
}

Describe 'Format-CheckReport' {
    It 'leads with what failed, by name' {
        $rows = @([pscustomobject]@{ Name = 'text'; Mark = '✓'; Link = 'u' }, [pscustomobject]@{ Name = 'unit tests'; Mark = '✗'; Link = 'u' })
        $report = Format-CheckReport $rows 'abc1234'
        $report | Should -Match '^<!-- ci-checks -->'
        $report | Should -Match '\*\*1 check failed: unit tests\*\*'
        $report | Should -Match '\| ✗ \| \[unit tests\]\(u\) \|'
    }
    It 'says when all pass, and when some are still running' {
        $done = @([pscustomobject]@{ Name = 'text'; Mark = '✓'; Link = 'u' })
        Format-CheckReport $done 'abc1234' | Should -Match '\*\*All 1 checks pass\*\*'
        $running = $done + @([pscustomobject]@{ Name = 'size'; Mark = '…'; Link = 'u' })
        Format-CheckReport $running 'abc1234' | Should -Match '1 still running'
    }
}

Describe 'Get-ReportCommentId' {
    It 'finds the report comment to edit' {
        $comments = @([pscustomobject]@{ id = 1; body = 'hello' }, [pscustomobject]@{ id = 2; body = "<!-- ci-checks -->`nold" })
        Get-ReportCommentId $comments | Should -Be 2
    }
}
