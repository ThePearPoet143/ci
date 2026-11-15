# Every script in ci parses (Pester 5). The checks' own tests load their functions, but not the Invoke-*.ps1 scripts CI
# runs, so a script that doesn't parse would only fail on a real pull request (as Invoke-Size.ps1 did on ci#1).
Describe 'Scripts' {
    It '<Name> parses' -ForEach @(Get-ChildItem $PSScriptRoot -Recurse -Filter *.ps1 | ForEach-Object { @{ Path = $_.FullName; Name = $_.Name } }) {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
        ($errors | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }) -join '; ' | Should -BeNullOrEmpty
    }
}
