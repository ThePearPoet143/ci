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

Describe 'Find-FixedCiRef' {
    It 'finds a call to ci at any fixed ref, but not the placeholder or a release title' {
        $text = @(
            'uses: ThePearPoet143/ci/.github/actions/size@vX.Y.Z'
            'uses: ThePearPoet143/ci/.github/actions/size@v1.2.3'
            'uses: thepearpoet143/ci/.github/actions/branch@main'
            'see ThePearPoet143/ci@v1'
            'titled chore(release): v1.2.3, what (HQ-1)'
        ) -join "`n"
        Find-FixedCiRef $text | Should -Be @('ThePearPoet143/ci/.github/actions/size@v1.2.3', 'thepearpoet143/ci/.github/actions/branch@main', 'ThePearPoet143/ci@v1')
    }
}

Describe 'Select-TagAt' {
    It 'names the tags already on a commit, so a rerun doesn''t release it twice' {
        $tags = @([pscustomobject]@{ name = 'v0.4.0'; commit = [pscustomobject]@{ sha = 'aaa' } }, [pscustomobject]@{ name = 'v0.5.0'; commit = [pscustomobject]@{ sha = 'bbb' } })
        Select-TagAt $tags 'bbb' | Should -Be 'v0.5.0'
        Select-TagAt $tags 'ccc' | Should -BeNullOrEmpty
    }
}

Describe 'This repo' {
    It 'names no fixed version of ci in its README or workflows, so they never go stale' {
        $root = "$PSScriptRoot/../.."
        $text = (@("$root/README.md") + @(Get-ChildItem "$root/.github/workflows" -Filter *.yml).FullName | ForEach-Object { [IO.File]::ReadAllText($_) }) -join "`n"
        (Find-FixedCiRef $text) -join ', ' | Should -BeNullOrEmpty
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
