# herd-php-autoswitch: make php, composer and artisan in the terminal use the PHP
# version pinned with `herd isolate` for the current site.
# https://github.com/HelgeSverre/herd-php-autoswitch

_herd_autoswitch_valet="$HOME/Library/Application Support/Herd/config/valet"
_herd_autoswitch_bin="$HOME/Library/Application Support/Herd/bin"
_herd_autoswitch_shims="$HOME/.cache/herd-php-autoswitch"
_herd_autoswitch_tld=$(sed -n 's/.*"tld": *"\([^"]*\)".*/\1/p' "$_herd_autoswitch_valet/config.json" 2>/dev/null)
: ${_herd_autoswitch_tld:=test}
# Parked paths (`herd park`): every folder directly inside one is a site named after the folder.
_herd_autoswitch_parked=()
() {
  local p
  for p in ${(f)"$(sed -n '/"paths"/,/]/s/^ *"\(.*\)",\{0,1\}$/\1/p' "$_herd_autoswitch_valet/config.json" 2>/dev/null)"}; do
    p=${p//\\\//\/}
    _herd_autoswitch_parked+=(${${p%/}:A})
  done
}

# Sets REPLY to the Herd site that contains $1 (empty if none), resolved the way Herd resolves it: a folder linked
# with `herd link` (named after the link), or a folder directly inside a parked path.
_herd_autoswitch_site() {
  local dir=${1:A} link
  local -A links
  REPLY=
  for link in "$_herd_autoswitch_valet"/Sites/*(N@); do
    links[${link:A}]=${link:t}
  done
  while [[ -n $dir && $dir != / ]]; do
    if [[ -n ${links[$dir]} ]]; then
      REPLY=${links[$dir]}
      return
    fi
    if (( ${#_herd_autoswitch_parked} == 0 )) && [[ -e "$_herd_autoswitch_valet/Nginx/${dir:t}.$_herd_autoswitch_tld" ]]; then
      REPLY=${dir:t} # Herd config unreadable: fall back to matching the folder name
      return
    fi
    if (( ${_herd_autoswitch_parked[(Ie)${dir:h}]} )); then
      REPLY=${dir:t}
      return
    fi
    dir=${dir:h}
  done
}

_herd_autoswitch_apply() {
  local REPLY site version= first_line
  _herd_autoswitch_site $PWD
  site=$REPLY
  local conf="$_herd_autoswitch_valet/Nginx/$site.$_herd_autoswitch_tld"

  if [[ -n $site && -r $conf ]]; then
    read -r first_line < $conf
    [[ $first_line == '# ISOLATED_PHP_VERSION='* ]] && version=${first_line#*=}
  fi

  path=(${path:#$_herd_autoswitch_shims/*})

  if [[ -z $version ]]; then
    _herd_autoswitch_warned=
    return
  fi
  if [[ ! -x "$_herd_autoswitch_bin/php${version//./}" ]]; then
    [[ $_herd_autoswitch_warned == $site ]] ||
      print -u2 -r -- "herd-php-autoswitch: $site.$_herd_autoswitch_tld is isolated to PHP $version, but PHP $version is not installed in Herd. Using the default PHP."
    _herd_autoswitch_warned=$site
    return
  fi

  local shim="$_herd_autoswitch_shims/${version//./}"
  if [[ ! -x $shim/php ]]; then
    mkdir -p $shim && ln -sf "$_herd_autoswitch_bin/php${version//./}" $shim/php
  fi
  path=($shim $path)
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
