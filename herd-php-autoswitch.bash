# herd-php-autoswitch: make php, composer and artisan in the terminal use the PHP
# version pinned with `herd isolate` for the current site.
# https://github.com/HelgeSverre/herd-php-autoswitch

_herd_autoswitch_valet="$HOME/Library/Application Support/Herd/config/valet"
_herd_autoswitch_bin="$HOME/Library/Application Support/Herd/bin"
_herd_autoswitch_shims="$HOME/.cache/herd-php-autoswitch"
_herd_autoswitch_tld=$(sed -n 's/.*"tld": *"\([^"]*\)".*/\1/p' "$_herd_autoswitch_valet/config.json" 2>/dev/null)
: "${_herd_autoswitch_tld:=test}"
# Parked paths (`herd park`): every folder directly inside one is a site named after the folder.
_herd_autoswitch_parked=()
while IFS= read -r _herd_autoswitch_p; do
  _herd_autoswitch_p=${_herd_autoswitch_p//\\\//\/}
  _herd_autoswitch_parked[${#_herd_autoswitch_parked[@]}]=$(cd "${_herd_autoswitch_p%/}" 2>/dev/null && pwd -P)
done < <(sed -n '/"paths"/,/]/s/^ *"\(.*\)",\{0,1\}$/\1/p' "$_herd_autoswitch_valet/config.json" 2>/dev/null)
unset _herd_autoswitch_p

# Sites linked with `herd link`, cached and reloaded when the Sites folder changes.
_herd_autoswitch_load_links() {
  local link target
  _herd_autoswitch_link_names=() _herd_autoswitch_link_targets=()
  for link in "$_herd_autoswitch_valet"/Sites/*; do
    [[ -L $link ]] || continue
    target=$(cd "$link" 2>/dev/null && pwd -P) || continue
    _herd_autoswitch_link_names[${#_herd_autoswitch_link_names[@]}]=${link##*/}
    _herd_autoswitch_link_targets[${#_herd_autoswitch_link_targets[@]}]=$target
  done
  mkdir -p "$_herd_autoswitch_shims" && : > "$_herd_autoswitch_shims/.links"
}

# Sets _herd_autoswitch_site to the Herd site that contains the current folder, resolved the
# way Herd resolves it: a folder linked with `herd link` (named after the link), or a folder
# directly inside a parked path.
_herd_autoswitch_find_site() {
  local dir i
  _herd_autoswitch_site=
  [[ "$_herd_autoswitch_valet/Sites" -nt "$_herd_autoswitch_shims/.links" ]] && _herd_autoswitch_load_links
  dir=$(pwd -P)
  while [[ -n $dir ]]; do
    for i in "${!_herd_autoswitch_link_targets[@]}"; do
      if [[ ${_herd_autoswitch_link_targets[$i]} == "$dir" ]]; then
        _herd_autoswitch_site=${_herd_autoswitch_link_names[$i]}
        return
      fi
    done
    if [[ ${#_herd_autoswitch_parked[@]} == 0 ]]; then
      # Herd config unreadable: fall back to matching the folder name.
      [[ -e "$_herd_autoswitch_valet/Nginx/${dir##*/}.$_herd_autoswitch_tld" ]] && { _herd_autoswitch_site=${dir##*/}; return; }
    else
      for i in "${_herd_autoswitch_parked[@]}"; do
        [[ $i == "${dir%/*}" ]] && { _herd_autoswitch_site=${dir##*/}; return; }
      done
    fi
    dir=${dir%/*}
  done
}

_herd_autoswitch_apply() {
  local rc=$?
  [[ $PWD == "$_herd_autoswitch_pwd" ]] && return $rc
  _herd_autoswitch_pwd=$PWD
  local version= first_line conf p new= IFS=:
  _herd_autoswitch_find_site
  conf="$_herd_autoswitch_valet/Nginx/$_herd_autoswitch_site.$_herd_autoswitch_tld"
  if [[ -n $_herd_autoswitch_site && -r $conf ]]; then
    read -r first_line < "$conf"
    [[ $first_line == '# ISOLATED_PHP_VERSION='* ]] && version=${first_line#*=}
  fi
  for p in $PATH; do
    [[ $p == "$_herd_autoswitch_shims"/* ]] || new=${new:+$new:}$p
  done
  PATH=$new
  if [[ -z $version ]]; then
    _herd_autoswitch_warned=
  elif [[ ! -x "$_herd_autoswitch_bin/php${version//./}" ]]; then
    [[ $_herd_autoswitch_warned == "$_herd_autoswitch_site" ]] ||
      echo "herd-php-autoswitch: $_herd_autoswitch_site.$_herd_autoswitch_tld is isolated to PHP $version, but PHP $version is not installed in Herd. Using the default PHP." >&2
    _herd_autoswitch_warned=$_herd_autoswitch_site
  else
    local shim="$_herd_autoswitch_shims/${version//./}"
    [[ -x $shim/php ]] || { mkdir -p "$shim" && ln -sf "$_herd_autoswitch_bin/php${version//./}" "$shim/php"; }
    PATH="$shim:$PATH"
  fi
  return $rc
}
[[ $PROMPT_COMMAND == *_herd_autoswitch_apply* ]] ||
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_herd_autoswitch_apply"
