BeforeAll {
    . "$PSScriptRoot\Comments.ps1"
}

Describe 'Find-CommentProblem' {
    It 'fails a comment that explains, and passes one that is only a source link' {
        Find-CommentProblem '# The labels, created once per repo' 'Invoke-Size.ps1' | Should -Match 'Invoke-Size.ps1:1'
        Find-CommentProblem '# https://cli.github.com/manual/gh_release_create' 'x.ps1' | Should -BeNullOrEmpty
    }
    It 'fails comment-based help and a comment after code' {
        Find-CommentProblem "<#`n.SYNOPSIS`n    Does things.`n#>" 'x.ps1' | Should -Not -BeNullOrEmpty
        Find-CommentProblem '$a = 1 # the count' 'x.ps1' | Should -Not -BeNullOrEmpty
    }
    It 'passes #Requires and a # inside a string' {
        Find-CommentProblem '#Requires -Version 5.1' 'x.ps1' | Should -BeNullOrEmpty
        Find-CommentProblem '$t = "# not a comment"' 'x.ps1' | Should -BeNullOrEmpty
    }
    It 'reads a YAML file''s comment lines the same way' {
        Find-CommentProblem "name: check`n# ci's own CI`non: push" 'check.yml' | Should -Match 'check.yml:2'
        Find-CommentProblem "# https://docs.github.com/en/actions`nname: check" 'check.yml' | Should -BeNullOrEmpty
        Find-CommentProblem "run: echo '# not a comment'" 'check.yml' | Should -BeNullOrEmpty
    }
}

Describe 'Get-SourceLink' {
    It 'lists each comment''s link' {
        Get-SourceLink "# https://a.example/x`n# https://b.example/y`n`$a = 1" 'x.ps1' | Should -Be @('https://a.example/x', 'https://b.example/y')
    }
}

Describe 'Test-SourceLink' {
    It 'names a link that does not resolve, with what it read' {
        $fetch = { param($Url) if ($Url -like '*dead*') { 'HTTP 404' } }
        Test-SourceLink @('https://a.example/live', 'https://a.example/dead') $fetch | Should -Be 'Source link https://a.example/dead: HTTP 404'
    }
}

Describe 'ci''s own files' {
    It 'have only source-link comments' {
        $root = Join-Path $PSScriptRoot '../..'
        $found = foreach ($file in Get-ChildItem $root -Recurse -Force -File -Include *.ps1, *.psm1, *.yml | Where-Object FullName -NotMatch '[\\/]\.git[\\/]') {
            Find-CommentProblem ([IO.File]::ReadAllText($file.FullName)) $file.Name
        }
        $found | Should -BeNullOrEmpty
    }
}
