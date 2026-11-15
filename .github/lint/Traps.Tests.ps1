BeforeAll {
    . "$PSScriptRoot\Traps.ps1"
    function Get-TrapRule([string]$Code, [string]$File = 'C:\x\Script.ps1') {
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($Code, $File, [ref]$null, [ref]$null)
        @(Find-Trap $ast | ForEach-Object { $_.Rule })
    }
}

Describe 'Find-Trap' {
    It 'flags @(... | ConvertFrom-Json), which holds a JSON array as one item in 5.1' {
        Get-TrapRule '$prs = @(gh pr list --json number | ConvertFrom-Json)' | Should -Be 'JsonArrayInArray'
        Get-TrapRule '$prs = @((gh pr list --json number | ConvertFrom-Json))' | Should -BeNullOrEmpty
    }
    It 'flags ConvertFrom-Json partway through a pipeline, which passes the whole array on as one item in 5.1' {
        Get-TrapRule '$names = $Labels | ConvertFrom-Json | ForEach-Object { $_.name }' | Should -Be 'JsonArrayMidPipeline'
        Get-TrapRule '$names = @(($Labels | ConvertFrom-Json)) | ForEach-Object { $_.name }' | Should -BeNullOrEmpty
    }
    It 'flags an empty argument to a program, which 5.1 drops' {
        Get-TrapRule "git config credential.helper ''" 'C:\x\Git.ps1' | Should -Be 'EmptyNativeArgument'
        Get-TrapRule "git config credential.helper '""""'" 'C:\x\Git.ps1' | Should -BeNullOrEmpty
        Get-TrapRule "Set-Content x ''" | Should -BeNullOrEmpty
    }
    It 'flags double quotes inside an argument to a program, which 5.1 drops' {
        Get-TrapRule "gh api repos/x/y --jq 'join("","")'" | Should -Be 'QuoteInNativeArgument'
        Get-TrapRule "gh api repos/x/y --jq '.[].name'" | Should -BeNullOrEmpty
        Get-TrapRule "cmd /c 'echo ""hi""'" | Should -BeNullOrEmpty
    }
    It 'flags gh api with a leading /, which Git Bash turns into a file path' {
        Get-TrapRule 'gh api /repos/x/y/commits' | Should -Be 'GhApiLeadingSlash'
        Get-TrapRule 'gh api -X POST /repos/x/y/labels' | Should -Be 'GhApiLeadingSlash'
        Get-TrapRule 'gh api --method POST repos/x/y/labels' | Should -BeNullOrEmpty
    }
    It 'flags a program''s redirected stderr under Stop, which 5.1 makes fatal' {
        Get-TrapRule "`$ErrorActionPreference = 'Stop'`ngh auth status 2>`$null" | Should -Be 'NativeStderrUnderStop'
        Get-TrapRule "`$ErrorActionPreference = 'Stop'`ngh auth status 2>&1" | Should -Be 'NativeStderrUnderStop'
        Get-TrapRule "`$script:ErrorActionPreference = 'Stop'`ngh auth status *>`$null" | Should -Be 'NativeStderrUnderStop'
        Get-TrapRule 'gh auth status 2>$null' | Should -BeNullOrEmpty
    }
    It 'reads Stop from the nearest setting before the command, so switching to Continue passes' {
        Get-TrapRule "`$ErrorActionPreference = 'Stop'`n`$ErrorActionPreference = 'Continue'`ngh auth status 2>`$null" | Should -BeNullOrEmpty
        Get-TrapRule "gh auth status 2>`$null`n`$ErrorActionPreference = 'Stop'" | Should -BeNullOrEmpty
    }
    It 'flags git called directly, whose failure reads as no output' {
        Get-TrapRule 'git diff --numstat "$Base...$Head"' | Should -Be 'GitWithoutInvokeGit'
        Get-TrapRule 'git.exe diff --numstat "$Base...$Head"' | Should -Be 'GitWithoutInvokeGit'
        Get-TrapRule 'Invoke-Git diff --numstat "$Base...$Head"' | Should -BeNullOrEmpty
        Get-TrapRule 'git init -q' 'C:\x\Git.Tests.ps1' | Should -BeNullOrEmpty
        Get-TrapRule '& git @args' 'C:\x\Git.ps1' | Should -BeNullOrEmpty
    }
    It 'names the fix in every message' {
        $ast = [System.Management.Automation.Language.Parser]::ParseInput('gh api /repos/x', 'C:\x\S.ps1', [ref]$null, [ref]$null)
        (Find-Trap $ast).Message | Should -Match 'repos/'
    }
}

Describe 'ci''s own scripts' {
    It 'have none of the traps' {
        $files = Get-ChildItem (Join-Path $PSScriptRoot '..') -Recurse -Force -File -Include *.ps1, *.psm1
        $found = foreach ($file in $files) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            Find-Trap $ast | ForEach-Object { "$($file.Name):$($_.Extent.StartLineNumber) $($_.Rule)" }
        }
        $found | Should -BeNullOrEmpty
    }
}
