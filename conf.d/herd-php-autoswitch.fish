# herd-php-autoswitch: make php, composer and artisan in the terminal use the PHP
# version pinned with `herd isolate` for the current site.
# https://github.com/HelgeSverre/herd-php-autoswitch

set -g __herd_autoswitch_valet "$HOME/Library/Application Support/Herd/config/valet"
set -g __herd_autoswitch_bin "$HOME/Library/Application Support/Herd/bin"
set -g __herd_autoswitch_shims "$HOME/.cache/herd-php-autoswitch"
set -g __herd_autoswitch_tld (cat $__herd_autoswitch_valet/config.json 2>/dev/null | string match -rg '"tld": *"([^"]*)"')
set -q __herd_autoswitch_tld[1]; or set __herd_autoswitch_tld test
# Parked paths (`herd park`): every folder directly inside one is a site named after the folder.
set -g __herd_autoswitch_parked
for p in (sed -n '/"paths"/,/]/s/^ *"\(.*\)",\{0,1\}$/\1/p' $__herd_autoswitch_valet/config.json 2>/dev/null)
    set -a __herd_autoswitch_parked (path resolve (string replace -a '\\/' / -- $p | string trim -r -c /))
end

# Prints the Herd site that contains $argv[1], resolved the way Herd resolves it: a folder
# linked with `herd link` (named after the link), or a folder directly inside a parked path.
function __herd_autoswitch_site
    set -l dir (path resolve $argv[1])
    set -l names
    set -l targets
    for link in $__herd_autoswitch_valet/Sites/*
        test -L $link; or continue
        set -a names (path basename $link)
        set -a targets (path resolve $link)
    end
    while test "$dir" != /
        if set -l i (contains -i -- $dir $targets)
            echo $names[$i]
            return
        end
        if not set -q __herd_autoswitch_parked[1]
            # Herd config unreadable: fall back to matching the folder name.
            if test -e "$__herd_autoswitch_valet/Nginx/"(path basename $dir).$__herd_autoswitch_tld
                path basename $dir
                return
            end
        else if contains -- (path dirname $dir) $__herd_autoswitch_parked
            path basename $dir
            return
        end
        set dir (path dirname $dir)
    end
end

# PWD covers cd; fish_preexec re-applies right before each command, after direnv and
# similar tools have updated PATH on the prompt, and after config.fish has run.
function __herd_autoswitch_apply --on-variable PWD --on-event fish_preexec
    set -l site (__herd_autoswitch_site $PWD)
    set -l php_version
    set -l conf "$__herd_autoswitch_valet/Nginx/$site.$__herd_autoswitch_tld"
    if test -n "$site"; and test -r $conf
        read -l first_line <$conf
        set php_version (string replace -f '# ISOLATED_PHP_VERSION=' '' -- $first_line)
    end
    set -gx PATH (string match -v -- "$__herd_autoswitch_shims/*" $PATH)
    if not set -q php_version[1]
        set -g __herd_autoswitch_warned
        return
    end
    if not test -x $__herd_autoswitch_bin/php(string replace -a . '' $php_version)
        if test "$__herd_autoswitch_warned" != "$site"
            echo "herd-php-autoswitch: $site.$__herd_autoswitch_tld is isolated to PHP $php_version, but PHP $php_version is not installed in Herd. Using the default PHP." >&2
        end
        set -g __herd_autoswitch_warned $site
        return
    end
    set -l shim $__herd_autoswitch_shims/(string replace -a . '' $php_version)
    if not test -x $shim/php
        mkdir -p $shim; and ln -sf $__herd_autoswitch_bin/php(string replace -a . '' $php_version) $shim/php
    end
    set -gx PATH $shim $PATH
end

# Fisher emits this after `fisher remove`.
function _herd-php-autoswitch_uninstall --on-event herd-php-autoswitch_uninstall
    set -gx PATH (string match -v -- "$__herd_autoswitch_shims/*" $PATH)
    functions -e __herd_autoswitch_apply
    functions -e __herd_autoswitch_site
    set -e __herd_autoswitch_valet __herd_autoswitch_bin __herd_autoswitch_shims __herd_autoswitch_tld __herd_autoswitch_parked __herd_autoswitch_warned
end
