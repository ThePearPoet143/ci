BeforeAll {
    . "$PSScriptRoot\Tools.ps1"
}

Describe 'Read-ToolPin' {
    It 'reads the exact version of each tool' {
        $pins = Read-ToolPin
        $pins.Pester | Should -Match '^\d+\.\d+\.\d+$'
        $pins.PSScriptAnalyzer | Should -Match '^\d+\.\d+\.\d+$'
    }
}

Describe 'Get-ToolProblem' {
    It 'passes when the pinned version is installed' {
        Get-ToolProblem 'Pester' '5.9.1' @('5.9.1', '3.4.0') | Should -BeNullOrEmpty
    }
    It 'names the install command when only other versions are installed' {
        Get-ToolProblem 'Pester' '5.9.1' @('5.9.0', '3.4.0') |
            Should -Be "Pester 5.9.1 isn't installed (found 5.9.0, 3.4.0): Install-Module Pester -RequiredVersion 5.9.1 -Scope CurrentUser"
    }
    It 'names the install command when the tool is missing' {
        Get-ToolProblem 'PSScriptAnalyzer' '1.25.0' @() |
            Should -Be "PSScriptAnalyzer 1.25.0 isn't installed (found none): Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser"
    }
}
