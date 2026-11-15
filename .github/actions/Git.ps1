# https://git-scm.com/docs/git-diff#_other_diff_formats
# https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_preference_variables#psnativecommanduseerroractionpreference

function Invoke-Git {
    $encoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    try {
        $out = & git @args
        if ($LASTEXITCODE) { throw "git $($args -join ' ') failed with exit code $LASTEXITCODE" }
        $out
    } finally {
        [Console]::OutputEncoding = $encoding
    }
}

function ConvertFrom-NumstatZ([string]$Text) {
    $fields = $Text -split "`0"
    for ($i = 0; $i -lt $fields.Count; $i++) {
        $added, $removed, $path = $fields[$i] -split "`t", 3
        if ($null -eq $path) { continue }
        if ($path -eq '') { $path = $fields[$i + 2]; $i += 2 }
        "$added`t$removed`t$path"
    }
}

function Get-Numstat([string]$Base, [string]$Head) {
    ConvertFrom-NumstatZ ((Invoke-Git diff --numstat -z "$Base...$Head") -join "`n")
}
