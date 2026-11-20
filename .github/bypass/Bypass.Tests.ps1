BeforeAll {
    . "$PSScriptRoot/Bypass.ps1"
    function Get-SamplePr($Number, $Base, $Checks, $Approved = 0) {
        [pscustomobject]@{ number = $Number; baseRefName = $Base; url = "https://github.com/o/r/pull/$Number"; approvals = $Approved; checks = @($Checks) }
    }
}

Describe 'Get-BypassReason' {
    It 'names each red check a PR merged with, as ci-sandbox#13 did' {
        $pr = Get-SamplePr 13 'dev' @(@{ name = 'core / text'; state = 'FAILURE' }, @{ name = 'core / branch'; state = 'FAILURE' }, @{ name = 'tests'; state = 'SUCCESS' })
        Get-BypassReason $pr | Should -Be @('merged with red checks: core / text, core / branch')
    }
    It 'passes a green PR into dev' {
        Get-BypassReason (Get-SamplePr 12 'dev' @(@{ name = 'tests'; state = 'SUCCESS' }, @{ name = 'CodeRabbit'; state = 'SKIPPED' })) | Should -BeNullOrEmpty
    }
    It 'flags a release into main merged with no approval' {
        Get-BypassReason (Get-SamplePr 30 'main' @(@{ name = 'tests'; state = 'SUCCESS' })) | Should -Be @('merged into main with no approval')
    }
    It 'judges each check by its latest run, as on ci#44, whose text check failed, then passed on a rerun' {
        $pr = Get-SamplePr 44 'dev' @(@{ name = 'text'; state = 'FAILURE'; at = '2026-11-20T16:30:00Z' }, @{ name = 'text'; state = 'SUCCESS'; at = '2026-11-20T16:36:00Z' })
        Get-BypassReason $pr | Should -BeNullOrEmpty
    }
    It 'counts a cancelled, timed-out or errored check as red' {
        $pr = Get-SamplePr 7 'dev' @(@{ name = 'a'; state = 'CANCELLED' }, @{ name = 'b'; state = 'TIMED_OUT' }, @{ name = 'review'; state = 'ERROR' })
        Get-BypassReason $pr | Should -Be @('merged with red checks: a, b, review')
    }
}

Describe 'Format-BypassReport' {
    It 'lists each bypass with its repo, link and reason' {
        $lines = Format-BypassReport @([pscustomobject]@{ Repo = 'o/r'; Number = 13; Url = 'https://github.com/o/r/pull/13'; Reasons = @('merged with red checks: core / text') })
        $lines -join "`n" | Should -Match 'o/r#13 https://github.com/o/r/pull/13: merged with red checks: core / text'
    }
    It 'says so when nothing was bypassed' {
        Format-BypassReport @() | Should -Be 'No bypasses.'
    }
}
