BeforeAll {
    . "$PSScriptRoot\Git.ps1"
    $script:repo = Join-Path ([IO.Path]::GetTempPath()) "ci-git-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory $script:repo | Out-Null
    Push-Location $script:repo
    git init -q
    git config user.email 'test@example.com'
    git config user.name 'test'
    New-Item -ItemType Directory src, dist | Out-Null
    Set-Content src/a.js 'one'
    Set-Content src/big.js (1..300 | ForEach-Object { "line $_" })
    git add .
    git commit -qm 'base'
    $script:base = git rev-parse HEAD
    New-Item -ItemType Directory vendor | Out-Null
    git mv src/a.js vendor/a.js
    git mv src/big.js src/moved.js
    Set-Content -Encoding utf8 'dist/café.js' 'two'
    git add .
    git commit -qm 'head'
    $script:head = git rev-parse HEAD
}

AfterAll {
    Pop-Location
    Remove-Item -Recurse -Force $script:repo
}

Describe 'Invoke-Git' {
    It 'returns what git prints' {
        Invoke-Git rev-parse HEAD | Should -Be $script:head
    }
    It 'fails when git fails, so a check can''t pass on nothing' {
        { Invoke-Git diff --numstat 'deadbeef...HEAD' } | Should -Throw '*git diff*'
    }
}

Describe 'ConvertFrom-NumstatZ' {
    It 'reads git''s -z records, naming a rename by its new path' {
        $z = "1`t2`tREADME`0" + "3`t1`t`0arch/i386/Makefile`0arch/x86/Makefile`0"
        ConvertFrom-NumstatZ $z | Should -Be @("1`t2`tREADME", "3`t1`tarch/x86/Makefile")
    }
}

Describe 'Get-Numstat' {
    It 'names a renamed file by its new path, and a non-ASCII path as it is' {
        $paths = Get-Numstat $script:base $script:head | ForEach-Object { ($_ -split "`t")[2] }
        $paths | Should -Contain 'vendor/a.js'
        $paths | Should -Contain 'dist/café.js'
        $paths | Should -Not -Contain 'src/a.js'
    }
    It 'counts a moved file as no changed lines' {
        Get-Numstat $script:base $script:head | Should -Contain "0`t0`tsrc/moved.js"
    }
}
