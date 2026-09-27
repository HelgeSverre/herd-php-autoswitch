# herd-php-autoswitch: make php and composer in PowerShell use the PHP version
# pinned with `herd isolate` for the current site (Laravel Herd for Windows).
# https://github.com/HelgeSverre/herd-php-autoswitch

$script:Valet = [IO.Path]::Combine($HOME, '.config', 'herd', 'config', 'valet')
$script:Bin = [IO.Path]::Combine($HOME, '.config', 'herd', 'bin')
$script:Added = $null
$script:Warned = $null
$config = try {
    Get-Content ([IO.Path]::Combine($script:Valet, 'config.json')) -Raw -ErrorAction Stop | ConvertFrom-Json
} catch { $null }
$script:Tld = if ($config -and $config.tld) { $config.tld } else { 'test' }

function ConvertTo-HerdPath($path) {
    [IO.Path]::GetFullPath($path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

# Parked paths (`herd park`): every folder directly inside one is a site named after the folder.
$script:Parked = @(if ($config) { $config.paths | Where-Object { $_ } | ForEach-Object { ConvertTo-HerdPath $_ } })

# The Herd site that contains $Dir, resolved the way Herd resolves it: a folder linked with
# `herd link` (named after the link), or a folder directly inside a parked path.
function Get-HerdSite($Dir) {
    $links = @{}
    $sites = [IO.Path]::Combine($script:Valet, 'Sites')
    if (Test-Path -LiteralPath $sites) {
        foreach ($link in Get-ChildItem -LiteralPath $sites -Force | Where-Object { $_.LinkType }) {
            $target = @($link.Target)[0]
            if ($target) { $links[(ConvertTo-HerdPath $target)] = $link.Name }
        }
    }
    $dir = ConvertTo-HerdPath $Dir
    while ($dir) {
        if ($links.ContainsKey($dir)) { return $links[$dir] }
        $name = Split-Path $dir -Leaf
        $parent = Split-Path $dir -Parent
        if ($script:Parked.Count -eq 0) {
            # Herd config unreadable: fall back to matching the folder name.
            $nginx = [IO.Path]::Combine($script:Valet, 'Nginx', "$name.$($script:Tld)")
            if ((Test-Path -LiteralPath "$nginx.conf") -or (Test-Path -LiteralPath $nginx)) { return $name }
        } elseif ($parent -and $script:Parked -contains (ConvertTo-HerdPath $parent)) {
            return $name
        }
        $dir = $parent
    }
}

function Update-HerdPhpAutoswitch {
    <#
    .SYNOPSIS
    Puts the isolated PHP version of the current Herd site first on PATH.
    Runs automatically after every location change; call it after `herd isolate`.
    #>
    $version = $null
    $site = if ($PWD.Provider.Name -eq 'FileSystem') { Get-HerdSite $PWD.ProviderPath }
    if ($site) {
        $nginx = [IO.Path]::Combine($script:Valet, 'Nginx', "$site.$($script:Tld)")
        $conf = "$nginx.conf", $nginx | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($conf -and (Get-Content -LiteralPath $conf -TotalCount 1) -match '^# ISOLATED_PHP_VERSION=(\S+)') {
            $version = $Matches[1]
        }
    }
    $folder = if ($version) { [IO.Path]::Combine($script:Bin, "php$($version -replace '\.')") }

    $sep = [IO.Path]::PathSeparator
    $paths = ($env:PATH -split $sep) -ne $script:Added
    $script:Added = $null
    if (-not $version) {
        $script:Warned = $null
    } elseif (-not (Test-Path -LiteralPath $folder)) {
        if ($script:Warned -ne $site) {
            Write-Warning "herd-php-autoswitch: $site.$($script:Tld) is isolated to PHP $version, but PHP $version is not installed in Herd. Using the default PHP."
        }
        $script:Warned = $site
    } else {
        $script:Added = $folder
    }
    $env:PATH = (@($script:Added) + $paths | Where-Object { $_ }) -join $sep
}

$invokeCommand = $ExecutionContext.SessionState.InvokeCommand
if ($invokeCommand.PSObject.Properties['LocationChangedAction']) {
    # PowerShell 6+: runs after every cd, Set-Location, Push-Location and Pop-Location.
    $script:Handler = [EventHandler[System.Management.Automation.LocationChangedEventArgs]] { Update-HerdPhpAutoswitch }
    $invokeCommand.LocationChangedAction = [Delegate]::Combine($invokeCommand.LocationChangedAction, $script:Handler)
} else {
    # Windows PowerShell 5.1 has no LocationChangedAction; run before each prompt instead,
    # keeping any existing prompt (oh-my-posh, starship).
    $script:OriginalPrompt = $function:global:prompt
    $function:global:prompt = {
        if ($PWD.Path -ne $script:LastPwd) {
            $script:LastPwd = $PWD.Path
            Update-HerdPhpAutoswitch
        }
        & $script:OriginalPrompt
    }
}

$ExecutionContext.SessionState.Module.OnRemove = {
    if ($script:Handler) {
        $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = [Delegate]::Remove(
            $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction, $script:Handler)
    }
    if ($script:OriginalPrompt) {
        $function:global:prompt = $script:OriginalPrompt
    }
    if ($script:Added) {
        $sep = [IO.Path]::PathSeparator
        $env:PATH = (($env:PATH -split $sep) -ne $script:Added) -join $sep
    }
}

Update-HerdPhpAutoswitch

Export-ModuleMember -Function Update-HerdPhpAutoswitch
