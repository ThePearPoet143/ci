Describe 'Scripts' {
    It '<Name> parses' -ForEach @(Get-ChildItem $PSScriptRoot -Recurse -Filter *.ps1 | ForEach-Object { @{ Path = $_.FullName; Name = $_.Name } }) {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
        ($errors | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }) -join '; ' | Should -BeNullOrEmpty
    }
}

Describe 'Commands in the docs' {
    It 'run with pwsh, which works on Windows, macOS and Linux' {
        $readme = [IO.File]::ReadAllText("$PSScriptRoot/../README.md")
        @([regex]::Matches($readme, '(?m)^powershell -File.*$') | ForEach-Object { $_.Value }) -join '; ' | Should -BeNullOrEmpty
    }
}
