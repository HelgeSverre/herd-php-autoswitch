# herd-php-autoswitch: make php, composer and artisan in the terminal use the PHP
# version pinned with `herd isolate` for the current site. macOS and Windows.
# https://github.com/HelgeSverre/herd-php-autoswitch

def --env __herd_autoswitch_apply [] {
    let windows = $nu.os-info.name == 'windows'
    # $nu.home-dir (home-path before Nushell 0.115) is fixed at startup; the variables are not.
    let home = (if $windows { $env.USERPROFILE? } else { $env.HOME? }) | default ($nu.home-dir? | default $nu.home-path?)
    let herd = if $windows {
        $home | path join '.config' 'herd'
    } else {
        $home | path join 'Library' 'Application Support' 'Herd'
    }
    let valet = $herd | path join 'config' 'valet'
    let tld = try { open ($valet | path join 'config.json') | get tld } catch { 'test' }

    mut version = ''
    mut dir = $env.PWD
    loop {
        let site = $valet | path join 'Nginx' $"($dir | path basename).($tld)"
        let conf = [$"($site).conf" $site] | where {|f| $f | path exists } | get 0?
        if $conf != null {
            let first_line = open --raw $conf | lines | get 0? | default ''
            if ($first_line | str starts-with '# ISOLATED_PHP_VERSION=') {
                $version = $first_line | str replace '# ISOLATED_PHP_VERSION=' '' | str replace --all '.' ''
            }
            break
        }
        let parent = $dir | path dirname
        if $parent == $dir { break }
        $dir = $parent
    }

    let previous = $env.__HERD_AUTOSWITCH_ADDED? | default ''
    $env.PATH = $env.PATH | where {|p| $p != $previous }
    $env.__HERD_AUTOSWITCH_ADDED = if $version == '' {
        ''
    } else if $windows {
        $herd | path join 'bin' $"php($version)"
    } else {
        let shim = $home | path join '.cache' 'herd-php-autoswitch' $version
        if not ($shim | path join 'php' | path exists) {
            mkdir $shim
            ^ln -sf ($herd | path join 'bin' $"php($version)") ($shim | path join 'php')
        }
        $shim
    }
    if $env.__HERD_AUTOSWITCH_ADDED != '' {
        $env.PATH = $env.PATH | prepend $env.__HERD_AUTOSWITCH_ADDED
    }
}

$env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD? | default [] | append {|before, after| __herd_autoswitch_apply }
)
