# herd-php-autoswitch: make php and composer in PowerShell use the PHP version
# pinned with `herd isolate` for the current site (Laravel Herd for Windows).
# https://github.com/HelgeSverre/herd-php-autoswitch

$script:Valet = [IO.Path]::Combine($HOME, '.config', 'herd', 'config', 'valet')
$script:Bin = [IO.Path]::Combine($HOME, '.config', 'herd', 'bin')
$script:Added = $null
$script:Tld = try {
    (Get-Content ([IO.Path]::Combine($script:Valet, 'config.json')) -Raw -ErrorAction Stop | ConvertFrom-Json).tld
} catch { $null }
if (-not $script:Tld) { $script:Tld = 'test' }

function Update-HerdPhpAutoswitch {
    <#
    .SYNOPSIS
    Puts the isolated PHP version of the current Herd site first on PATH.
    Runs automatically after every location change; call it after `herd isolate`.
    #>
    $version = $null
    $dir = if ($PWD.Provider.Name -eq 'FileSystem') { $PWD.ProviderPath }
    while ($dir -and -not $version) {
        $site = [IO.Path]::Combine($script:Valet, 'Nginx', "$(Split-Path $dir -Leaf).$($script:Tld)")
        $conf = "$site.conf", $site | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($conf) {
            if ((Get-Content -LiteralPath $conf -TotalCount 1) -match '^# ISOLATED_PHP_VERSION=(\S+)') {
                $version = $Matches[1] -replace '\.'
            }
            break
        }
        $dir = Split-Path $dir -Parent
    }
    $sep = [IO.Path]::PathSeparator
    $paths = ($env:PATH -split $sep) -ne $script:Added
    $script:Added = if ($version) { [IO.Path]::Combine($script:Bin, "php$version") }
    $env:PATH = (@($script:Added) + $paths | Where-Object { $_ }) -join $sep
}

$script:Handler = [EventHandler[System.Management.Automation.LocationChangedEventArgs]] { Update-HerdPhpAutoswitch }
$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = [Delegate]::Combine(
    $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction, $script:Handler)

$ExecutionContext.SessionState.Module.OnRemove = {
    $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = [Delegate]::Remove(
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction, $script:Handler)
    if ($script:Added) {
        $sep = [IO.Path]::PathSeparator
        $env:PATH = (($env:PATH -split $sep) -ne $script:Added) -join $sep
    }
}

Update-HerdPhpAutoswitch

Export-ModuleMember -Function Update-HerdPhpAutoswitch
