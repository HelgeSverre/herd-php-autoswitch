# herd-php-autoswitch: make php, composer and artisan in the terminal use the PHP
# version pinned with `herd isolate` for the current site.
# https://github.com/HelgeSverre/herd-php-autoswitch

set -g __herd_autoswitch_valet "$HOME/Library/Application Support/Herd/config/valet"
set -g __herd_autoswitch_bin "$HOME/Library/Application Support/Herd/bin"
set -g __herd_autoswitch_shims "$HOME/.cache/herd-php-autoswitch"
set -g __herd_autoswitch_tld (cat $__herd_autoswitch_valet/config.json 2>/dev/null | string match -rg '"tld": *"([^"]*)"')
set -q __herd_autoswitch_tld[1]; or set __herd_autoswitch_tld test

# PWD covers cd; fish_preexec re-applies right before each command, after direnv and
# similar tools have updated PATH on the prompt, and after config.fish has run.
function __herd_autoswitch_apply --on-variable PWD --on-event fish_preexec
    set -l dir $PWD
    set -l php_version
    while test "$dir" != /
        set -l conf "$__herd_autoswitch_valet/Nginx/"(path basename $dir).$__herd_autoswitch_tld
        if test -r $conf
            read -l first_line <$conf
            set php_version (string replace -f '# ISOLATED_PHP_VERSION=' '' -- $first_line)
            break
        end
        set dir (path dirname $dir)
    end
    set -gx PATH (string match -v -- "$__herd_autoswitch_shims/*" $PATH)
    if set -q php_version[1]
        set -l shim $__herd_autoswitch_shims/(string replace -a . '' $php_version)
        if not test -x $shim/php
            mkdir -p $shim; and ln -sf $__herd_autoswitch_bin/php(string replace -a . '' $php_version) $shim/php
        end
        set -gx PATH $shim $PATH
    end
end

# Fisher emits this after `fisher remove`.
function _herd-php-autoswitch_uninstall --on-event herd-php-autoswitch_uninstall
    set -gx PATH (string match -v -- "$__herd_autoswitch_shims/*" $PATH)
    functions -e __herd_autoswitch_apply
    set -e __herd_autoswitch_valet __herd_autoswitch_bin __herd_autoswitch_shims __herd_autoswitch_tld
end
