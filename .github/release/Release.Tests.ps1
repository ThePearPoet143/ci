BeforeAll {
    . "$PSScriptRoot\Release.ps1"
}

Describe 'Test-ReleasePr' {
    It 'takes the version and the release title from the PR''s title' {
        $release = Test-ReleasePr 'chore(release): v0.2.0, more checks (HQ-9)' @('v0.1.0')
        $release.Version | Should -Be 'v0.2.0'
        $release.Title | Should -Be 'v0.2.0: more checks'
    }
    It 'fails a title that isn''t a release title, or names a short or pre-release version' {
        foreach ($title in 'chore: v0.2.0, more checks (HQ-9)', 'chore(release): v0.2, more (HQ-9)', 'chore(release): v0.2.0-rc.1, more (HQ-9)') {
            { Test-ReleasePr $title @() } | Should -Throw "*chore(release)*"
        }
    }
    It 'fails a release PR whose version is already released' {
        { Test-ReleasePr 'chore(release): v0.1.0, again (HQ-9)' @('v0.1.0') } | Should -Throw '*already released*'
    }
}

Describe 'This repo' {
    It 'names no fixed version of ci in its README, so its examples never go stale' {
        $readme = [IO.File]::ReadAllText("$PSScriptRoot/../../README.md")
        @([regex]::Matches($readme, '(?i)ThePearPoet143/ci/\S+@v\d+\.\d+\.\d+') | ForEach-Object { $_.Value }) -join ', ' | Should -BeNullOrEmpty
    }
}

Describe 'Get-ReleaseNote' {
    It 'is the release PR''s Change, without the model line' {
        $body = "## Problem`n`nci#3 isn't released.`n`n## Change`n`nReleases v0.1.0.`n`nIssues released: HQ-1, HQ-2.`n`n## Verification`n`n- ci#3`n`nmodel line"
        Get-ReleaseNote $body | Should -Be "Releases v0.1.0.`n`nIssues released: HQ-1, HQ-2."
    }
    It 'leaves out the model line when Change is the last section' {
        $body = "## Change`n`nReleases v0.1.0.`n`nIssues released: HQ-1, HQ-2.`n`nmodel line"
        Get-ReleaseNote $body | Should -Be "Releases v0.1.0.`n`nIssues released: HQ-1, HQ-2."
    }
    It 'fails a body with no Change' {
        { Get-ReleaseNote 'nothing here' } | Should -Throw '*Change*'
    }
}
