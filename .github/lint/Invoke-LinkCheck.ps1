# https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/invoke-webrequest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Comments.ps1"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$links = @(foreach ($file in Get-SourceFile (Join-Path $PSScriptRoot '../..')) {
        Get-SourceLink ([IO.File]::ReadAllText($file)) ([IO.Path]::GetFileName($file))
    })
$fetch = {
    param($Url)
    $problem = $null
    foreach ($try in 1..3) {
        try {
            $response = Invoke-WebRequest (Get-LinkToFetch $Url) -UseBasicParsing -TimeoutSec 30
            Write-Output "Read $Url`: HTTP $($response.StatusCode), try $try" | Out-Host
            return
        } catch {
            $problem = "$($_.Exception.Message) (after $try tries)"
            if ($try -lt 3) { Start-Sleep -Seconds 5 }
        }
    }
    $problem
}
$dead = @(Test-SourceLink $links $fetch)
$dead | ForEach-Object { Write-Output $_ }
Write-Output "Source links: $(@($links | Sort-Object -Unique).Count) read, $($dead.Count) dead."
if ($dead) { exit 1 }
