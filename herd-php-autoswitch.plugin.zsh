# herd-php-autoswitch: make php, composer and artisan in the terminal use the PHP
# version pinned with `herd isolate` for the current site.
# https://github.com/HelgeSverre/herd-php-autoswitch

_herd_autoswitch_valet="$HOME/Library/Application Support/Herd/config/valet"
_herd_autoswitch_bin="$HOME/Library/Application Support/Herd/bin"
_herd_autoswitch_shims="$HOME/.cache/herd-php-autoswitch"
_herd_autoswitch_tld=$(sed -n 's/.*"tld": *"\([^"]*\)".*/\1/p' "$_herd_autoswitch_valet/config.json" 2>/dev/null)
: ${_herd_autoswitch_tld:=test}

_herd_autoswitch_apply() {
  local dir=$PWD version= first_line conf

  while [[ -n $dir && $dir != / ]]; do
    conf="$_herd_autoswitch_valet/Nginx/${dir:t}.$_herd_autoswitch_tld"
    if [[ -r $conf ]]; then
      read -r first_line < $conf
      [[ $first_line == '# ISOLATED_PHP_VERSION='* ]] && version=${first_line#*=}
      break
    fi
    dir=${dir:h}
  done

  path=(${path:#$_herd_autoswitch_shims/*})

  if [[ -n $version ]]; then
    local shim="$_herd_autoswitch_shims/${version//./}"
    if [[ ! -x $shim/php ]]; then
      mkdir -p $shim && ln -sf "$_herd_autoswitch_bin/php${version//./}" $shim/php
    fi
    path=($shim $path)
  fi
}

# Apply once at the first prompt as well, after the rest of .zshrc (e.g. Herd's own PATH
# line) has run, so the load order in .zshrc doesn't matter.
_herd_autoswitch_init() {
  add-zsh-hook -d precmd _herd_autoswitch_init
  _herd_autoswitch_apply
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _herd_autoswitch_apply
add-zsh-hook precmd _herd_autoswitch_init
_herd_autoswitch_apply
