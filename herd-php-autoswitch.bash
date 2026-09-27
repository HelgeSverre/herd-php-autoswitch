# herd-php-autoswitch: make php, composer and artisan in the terminal use the PHP
# version pinned with `herd isolate` for the current site.
# https://github.com/HelgeSverre/herd-php-autoswitch

_herd_autoswitch_valet="$HOME/Library/Application Support/Herd/config/valet"
_herd_autoswitch_bin="$HOME/Library/Application Support/Herd/bin"
_herd_autoswitch_shims="$HOME/.cache/herd-php-autoswitch"
_herd_autoswitch_tld=$(sed -n 's/.*"tld": *"\([^"]*\)".*/\1/p' "$_herd_autoswitch_valet/config.json" 2>/dev/null)
: "${_herd_autoswitch_tld:=test}"

_herd_autoswitch_apply() {
  local rc=$?
  [[ $PWD == "$_herd_autoswitch_pwd" ]] && return $rc
  _herd_autoswitch_pwd=$PWD
  local dir=$PWD version= first_line conf p new= IFS=:
  while [[ -n $dir ]]; do
    conf="$_herd_autoswitch_valet/Nginx/${dir##*/}.$_herd_autoswitch_tld"
    if [[ -r $conf ]]; then
      read -r first_line < "$conf"
      [[ $first_line == '# ISOLATED_PHP_VERSION='* ]] && version=${first_line#*=}
      break
    fi
    dir=${dir%/*}
  done
  for p in $PATH; do
    [[ $p == "$_herd_autoswitch_shims"/* ]] || new=${new:+$new:}$p
  done
  PATH=$new
  if [[ -n $version ]]; then
    local shim="$_herd_autoswitch_shims/${version//./}"
    [[ -x $shim/php ]] || { mkdir -p "$shim" && ln -sf "$_herd_autoswitch_bin/php${version//./}" "$shim/php"; }
    PATH="$shim:$PATH"
  fi
  return $rc
}
[[ $PROMPT_COMMAND == *_herd_autoswitch_apply* ]] ||
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_herd_autoswitch_apply"
