BeforeAll {
    . "$PSScriptRoot\Release.ps1"
}

Describe 'Get-ReleaseVersion' {
    It 'returns the one version the calls name' {
        $text = @(
            '      - uses: ThePearPoet143/ci/.github/actions/text-check@v0.1.0'
            '      - uses: actions/checkout@v7.0.1'
            '      - uses: ThePearPoet143/ci/.github/actions/size@v0.1.0'
        ) -join "`n"
        Get-ReleaseVersion $text | Should -Be 'v0.1.0'
    }
    It 'fails when the calls name more than one version' {
        $text = "uses: ThePearPoet143/ci/.github/actions/size@v0.1.0`nuses: ThePearPoet143/ci/.github/actions/branch@v0.0.9"
        { Get-ReleaseVersion $text } | Should -Throw '*v0.0.9, v0.1.0*'
    }
    It 'fails when nothing calls ci' {
        { Get-ReleaseVersion 'uses: actions/checkout@v7.0.1' } | Should -Throw '*no version*'
    }
}

Describe 'This repo' {
    It 'names one ci version in its README and workflows' {
        Get-ReleaseVersion (Read-VersionedText) | Should -Match '^v\d+\.\d+\.\d+$'
    }
}

Describe 'Get-ReleaseTitle' {
    It 'turns the release PR title into the release name' {
        Get-ReleaseTitle 'chore(release): v0.1.0, the first checks (HQ-2)' 'v0.1.0' | Should -Be 'v0.1.0: the first checks'
    }
    It 'fails a release PR whose title names another version' {
        { Get-ReleaseTitle 'chore(release): v0.0.9, the first checks (HQ-2)' 'v0.1.0' } | Should -Throw '*v0.0.9*v0.1.0*'
    }
    It 'fails a title that is not a release title' {
        { Get-ReleaseTitle 'feat(size): a new label (HQ-50)' 'v0.1.0' } | Should -Throw '*chore(release)*'
    }
}

Describe 'Get-ReleaseNote' {
    It 'is the release PR''s What and why, without the model line' {
        $body = "## What and why`n`nReleases v0.1.0.`n`nIssues released: HQ-1, HQ-2.`n`n## Proven`n`n- ci#3`n`nmodel line"
        Get-ReleaseNote $body | Should -Be "Releases v0.1.0.`n`nIssues released: HQ-1, HQ-2."
    }
    It 'leaves out the model line when What and why is the last section' {
        $body = "## What and why`n`nReleases v0.1.0.`n`nIssues released: HQ-1, HQ-2.`n`nmodel line"
        Get-ReleaseNote $body | Should -Be "Releases v0.1.0.`n`nIssues released: HQ-1, HQ-2."
    }
    It 'fails a body with no What and why' {
        { Get-ReleaseNote 'nothing here' } | Should -Throw '*What and why*'
    }
}
