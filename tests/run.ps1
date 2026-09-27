# Tests the HerdPhpAutoswitch module against a fake Herd for Windows install.
# Runs on PowerShell 7 (any OS) and Windows PowerShell 5.1: pwsh -NoProfile -File tests/run.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$onWindows = $env:OS -eq 'Windows_NT'
$sep = [IO.Path]::PathSeparator
$mock = Join-Path ([IO.Path]::GetTempPath()) "herd-php-autoswitch-$([guid]::NewGuid())"
$bin = [IO.Path]::Combine($mock, '.config', 'herd', 'bin')
$valet = [IO.Path]::Combine($mock, '.config', 'herd', 'config', 'valet')

function New-FakeCommand($dir, $name, $windowsBody, $unixBody) {
    New-Item -ItemType Directory -Force $dir | Out-Null
    if ($onWindows) {
        Set-Content -LiteralPath (Join-Path $dir "$name.bat") $windowsBody
    } else {
        $file = Join-Path $dir $name
        Set-Content -LiteralPath $file "#!/bin/sh`n$unixBody"
        chmod +x $file
    }
}

New-FakeCommand $bin 'php' '@echo 8.4.0' 'echo 8.4.0'
foreach ($v in '82', '83', '84') {
    $version = "$($v[0]).$($v[1]).0"
    New-FakeCommand (Join-Path $bin "php$v") 'php' "@echo $version" "echo $version"
}
New-FakeCommand $bin 'composer' '@php %*' 'exec php "$@"'

New-Item -ItemType Directory -Force (Join-Path $valet 'Nginx') | Out-Null
Set-Content (Join-Path $valet 'config.json') '{ "tld": "test" }'
Set-Content (Join-Path $valet 'Nginx/my-project.test.conf') "# ISOLATED_PHP_VERSION=8.3`nserver {}"
Set-Content (Join-Path $valet 'Nginx/legacy.test.conf') "# ISOLATED_PHP_VERSION=8.2`nserver {}"
Set-Content (Join-Path $valet 'Nginx/other-project.test.conf') 'server {}'
foreach ($d in 'Herd/my-project/app/Models', 'Herd/legacy', 'Herd/other-project', 'elsewhere') {
    New-Item -ItemType Directory -Force (Join-Path $mock $d) | Out-Null
}

Set-Variable -Name HOME -Value $mock -Force -Scope Global
$env:PATH = "$bin$sep$env:PATH"

# PowerShell 6+ hooks LocationChangedAction; Windows PowerShell 5.1 has none, so the module
# wraps `prompt` instead. Either way, a hook that existed before the module must keep running.
$promptMode = -not $ExecutionContext.SessionState.InvokeCommand.PSObject.Properties['LocationChangedAction']
$global:otherHandlerCalls = 0
if ($promptMode) {
    function global:prompt { $global:otherHandlerCalls++; 'PS> ' }
} else {
    $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction =
        [EventHandler[System.Management.Automation.LocationChangedEventArgs]] { $global:otherHandlerCalls++ }
}

Import-Module (Join-Path $root 'HerdPhpAutoswitch') -Force

$failures = 0
function Test-Step($label, $expected) {
    if ($promptMode) { prompt | Out-Null }  # the REPL draws a prompt after each command
    $php = (& php | Out-String).Trim()
    $composer = (& composer | Out-String).Trim()
    $added = @(($env:PATH -split $sep) | Where-Object { $_ -like "*herd*bin*php8*" }).Count
    if ($php -eq $expected -and $composer -eq $expected -and $added -le 1) {
        "  ok   $label`: php $php, composer $composer"
    } else {
        "  FAIL $label`: php '$php' composer '$composer' added '$added' (expected $expected)"
        $script:failures++
    }
}

$hookName = if ($promptMode) { 'prompt' } else { 'LocationChangedAction' }
"PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition)), hook: $hookName"
Set-Location (Join-Path $mock 'Herd/my-project');            Test-Step 'my-project' '8.3.0'
Set-Location (Join-Path $mock 'Herd/my-project/app/Models'); Test-Step 'subdirectory' '8.3.0'
Set-Location (Join-Path $mock 'Herd/legacy');                Test-Step 'legacy' '8.2.0'
Set-Location (Join-Path $mock 'Herd/other-project');         Test-Step 'other-project' '8.4.0'
Set-Location (Join-Path $mock 'elsewhere');                  Test-Step 'elsewhere' '8.4.0'
Set-Location $mock;                                          Test-Step 'home' '8.4.0'
Push-Location (Join-Path $mock 'Herd/my-project');           Test-Step 'push-location' '8.3.0'
Pop-Location;                                                Test-Step 'pop-location' '8.4.0'

if ($global:otherHandlerCalls -gt 0) { "  ok   existing hook still runs ($global:otherHandlerCalls calls)" }
else { "  FAIL existing hook was replaced"; $failures++ }

Set-Location (Join-Path $mock 'Herd/my-project')
Remove-Module HerdPhpAutoswitch
Test-Step 'after Remove-Module (PATH entry removed)' '8.4.0'
Set-Location (Join-Path $mock 'Herd/legacy');                Test-Step 'after Remove-Module (no longer switching)' '8.4.0'
$before = $global:otherHandlerCalls
Set-Location $mock
if ($promptMode) { prompt | Out-Null }
if ($global:otherHandlerCalls -gt $before) { "  ok   existing hook restored after Remove-Module" }
else { "  FAIL Remove-Module did not restore the existing hook"; $failures++ }

Set-Location ([IO.Path]::GetTempPath())
Remove-Item -LiteralPath $mock -Recurse -Force
if ($failures) { "$failures failure(s)"; exit 1 }
'all passed'
