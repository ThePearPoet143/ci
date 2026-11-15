Describe 'Scripts' {
    It '<Name> parses' -ForEach @(Get-ChildItem $PSScriptRoot -Recurse -Filter *.ps1 | ForEach-Object { @{ Path = $_.FullName; Name = $_.Name } }) {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
        ($errors | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }) -join '; ' | Should -BeNullOrEmpty
    }
}
