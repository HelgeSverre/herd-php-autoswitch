# herd-php-autoswitch: make php, composer and artisan in the terminal use the PHP
# version pinned with `herd isolate` for the current site. macOS and Windows.
# https://github.com/HelgeSverre/herd-php-autoswitch

# The Herd site that contains $dir, resolved the way Herd resolves it: a folder linked with
# `herd link` (named after the link), or a folder directly inside a parked path.
def __herd_autoswitch_site [valet: string, tld: string, dir: string] {
    let config = try { open ($valet | path join 'config.json') } catch { {} }
    let parked = $config.paths? | default [] | each {|p| $p | path expand }
    let sites = $valet | path join 'Sites'
    let links = if ($sites | path exists) {
        ls -l $sites | where type == symlink | each {|l| { name: ($l.name | path basename), target: ($l.name | path expand) } }
    } else { [] }

    mut current = $dir | path expand
    loop {
        let link = $links | where target == $current | get 0?
        if $link != null { return $link.name }
        let name = $current | path basename
        if ($parked | is-empty) {
            # Herd config unreadable: fall back to matching the folder name.
            let nginx = $valet | path join 'Nginx' $"($name).($tld)"
            if ($nginx | path exists) or ($"($nginx).conf" | path exists) { return $name }
        } else if ($current | path dirname) in $parked {
            return $name
        }
        let parent = $current | path dirname
        if $parent == $current { return null }
        $current = $parent
    }
}

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

    let site = __herd_autoswitch_site $valet $tld $env.PWD
    mut version = ''
    if $site != null {
        let nginx = $valet | path join 'Nginx' $"($site).($tld)"
        let conf = [$"($nginx).conf" $nginx] | where {|f| $f | path exists } | get 0?
        if $conf != null {
            let first_line = open --raw $conf | lines | get 0? | default ''
            if ($first_line | str starts-with '# ISOLATED_PHP_VERSION=') {
                $version = $first_line | str replace '# ISOLATED_PHP_VERSION=' ''
            }
        }
    }
    let digits = $version | str replace --all '.' ''
    # macOS: the php83 binary. Windows: the php83 folder that holds php.exe.
    let binary = $herd | path join 'bin' $"php($digits)"

    let previous = $env.__HERD_AUTOSWITCH_ADDED? | default ''
    $env.PATH = $env.PATH | where {|p| $p != $previous }
    $env.__HERD_AUTOSWITCH_ADDED = ''
    if $version == '' {
        $env.__HERD_AUTOSWITCH_WARNED = ''
        return
    }
    if not ($binary | path exists) {
        if ($env.__HERD_AUTOSWITCH_WARNED? | default '') != $site {
            print -e $"herd-php-autoswitch: ($site).($tld) is isolated to PHP ($version), but PHP ($version) is not installed in Herd. Using the default PHP."
        }
        $env.__HERD_AUTOSWITCH_WARNED = $site
        return
    }
    $env.__HERD_AUTOSWITCH_ADDED = if $windows {
        $binary
    } else {
        let shim = $home | path join '.cache' 'herd-php-autoswitch' $digits
        if not ($shim | path join 'php' | path exists) {
            mkdir $shim
            ^ln -sf $binary ($shim | path join 'php')
        }
        $shim
    }
    $env.PATH = $env.PATH | prepend $env.__HERD_AUTOSWITCH_ADDED
}

$env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD? | default [] | append {|before, after| __herd_autoswitch_apply }
)
