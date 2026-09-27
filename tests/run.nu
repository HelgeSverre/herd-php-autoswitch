# Tests the Nushell hook's switching logic against a fake Herd install for the current OS.
# Usage: nu -n tests/run.nu     (tests/nu-repl.exp checks that the hook fires in the REPL)
let root = $env.FILE_PWD | path dirname
let windows = $nu.os-info.name == 'windows'
let mock = $nu.temp-dir | path join $"herd-php-autoswitch-(random uuid)"
let herd = if $windows { $mock | path join '.config' 'herd' } else { $mock | path join 'Library' 'Application Support' 'Herd' }
let bin = $herd | path join 'bin'
let nginx = $herd | path join 'config' 'valet' 'Nginx'
let suffix = if $windows { '.conf' } else { '' }
let shims = $mock | path join '.cache' 'herd-php-autoswitch'

def fake-command [dir: string, name: string, windows_body: string, unix_body: string] {
    mkdir $dir
    if $nu.os-info.name == 'windows' {
        $windows_body | save -f ($dir | path join $"($name).bat")
    } else {
        $"#!/bin/sh\n($unix_body)\n" | save -f ($dir | path join $name)
        ^chmod +x ($dir | path join $name)
    }
}

# macOS keeps php82, php83 ... next to php; Windows keeps one folder per version.
fake-command $bin 'php' '@echo 8.4.0' 'echo 8.4.0'
for v in ['82' '83' '84'] {
    let version = $"($v | str substring 0..0).($v | str substring 1..1).0"
    if $windows {
        fake-command ($bin | path join $"php($v)") 'php' $"@echo ($version)" $"echo ($version)"
    } else {
        fake-command $bin $"php($v)" $"@echo ($version)" $"echo ($version)"
    }
}
fake-command $bin 'composer' '@php %*' 'exec php "$@"'

mkdir $nginx
let valet = $nginx | path dirname
# ~/Herd is parked; ~/Code/worktree-folder is linked as "linked-app"; ~/elsewhere/my-project is not a site.
{ tld: 'test', paths: [($valet | path join 'Sites') ($mock | path join 'Herd')] } | to json | save -f ($valet | path join 'config.json')
"# ISOLATED_PHP_VERSION=8.3\nserver {}\n" | save -f ($nginx | path join $"my-project.test($suffix)")
"# ISOLATED_PHP_VERSION=8.2\nserver {}\n" | save -f ($nginx | path join $"legacy.test($suffix)")
"server {}\n" | save -f ($nginx | path join $"other-project.test($suffix)")
"# ISOLATED_PHP_VERSION=8.2\nserver {}\n" | save -f ($nginx | path join $"docs.test($suffix)")
"# ISOLATED_PHP_VERSION=8.1\nserver {}\n" | save -f ($nginx | path join $"old-app.test($suffix)")
"# ISOLATED_PHP_VERSION=8.2\nserver {}\n" | save -f ($nginx | path join $"linked-app.test($suffix)")
for d in ['Herd/my-project/app/Models' 'Herd/my-project/docs' 'Herd/legacy' 'Herd/other-project' 'Herd/old-app' 'Code/worktree-folder/src' 'elsewhere/my-project'] { mkdir ($mock | path join $d) }
mkdir ($valet | path join 'Sites')
let link = $valet | path join 'Sites' 'linked-app'
let target = $mock | path join 'Code' 'worktree-folder'
if $windows { ^cmd /c mklink /J $link $target | ignore } else { ^ln -s $target $link }

$env.HOME = $mock
$env.USERPROFILE = $mock
$env.PATH = $env.PATH | prepend $bin
source ../herd-php-autoswitch.nu

print $"Nushell (version | get version) on ($nu.os-info.name)"
mut failures = 0
for step in [
    [label dir expected];
    [my-project 'Herd/my-project' '8.3.0']
    [subdirectory 'Herd/my-project/app/Models' '8.3.0']
    [docs-subfolder 'Herd/my-project/docs' '8.3.0']
    [legacy 'Herd/legacy' '8.2.0']
    [other-project 'Herd/other-project' '8.4.0']
    [linked-site 'Code/worktree-folder' '8.2.0']
    [linked-subfolder 'Code/worktree-folder/src' '8.2.0']
    [same-name-not-a-site 'elsewhere/my-project' '8.4.0']
    [missing-version 'Herd/old-app' '8.4.0']
    [elsewhere 'elsewhere' '8.4.0']
    [home '.' '8.4.0']
    [re-enter 'Herd/my-project' '8.3.0']
] {
    cd ($mock | path join $step.dir)
    __herd_autoswitch_apply
    let php = ^php | str trim
    let composer = ^composer | str trim
    let added = $env.PATH | where {|p| ($p | str starts-with $shims) or ($p =~ 'php8\d$') } | length
    if $php == $step.expected and $composer == $step.expected and $added <= 1 {
        print $"  ok   ($step.label): php ($php), composer ($composer)"
    } else {
        print $"  FAIL ($step.label): php '($php)' composer '($composer)' added ($added) \(expected ($step.expected)\)"
        $failures += 1
    }
}

# The missing-version step records that it warned about old-app (printed once, to stderr).
cd ($mock | path join 'Herd' 'old-app')
__herd_autoswitch_apply
if ($env.__HERD_AUTOSWITCH_WARNED? | default '') == 'old-app' {
    print '  ok   warns about the missing PHP 8.1'
} else {
    print '  FAIL no warning recorded for the missing PHP 8.1'
    $failures += 1
}

cd $nu.temp-dir
rm -rf $mock
if $failures > 0 { print $"($failures) failure\(s\)"; exit 1 }
print 'all passed'
