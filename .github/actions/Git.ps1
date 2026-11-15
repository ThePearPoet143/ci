# https://git-scm.com/docs/git-config#Documentation/git-config.txt-corequotePath
# https://git-scm.com/docs/git-diff#Documentation/git-diff.txt---no-renames
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

function Get-Numstat([string]$Base, [string]$Head) {
    Invoke-Git -c core.quotePath=false diff --numstat --no-renames "$Base...$Head"
}
