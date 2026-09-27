#!/bin/sh
# Undoes docs/demo/setup.zsh: unisolates and unlinks the demo site, removes the
# ~/.herd-php-autoswitch link and the shim cache. Run from the repo root after vhs.
set -u
sites=$(cat docs/demo/.sites 2>/dev/null) || { echo "no demo site recorded"; exit 0; }
if [ -d "$sites/my-project" ]; then
  (cd "$sites/my-project" && herd unisolate >/dev/null 2>&1; herd unlink >/dev/null 2>&1)
fi
[ -L "$HOME/.herd-php-autoswitch" ] && rm "$HOME/.herd-php-autoswitch"
rm -rf "$HOME/.cache/herd-php-autoswitch" "$(dirname "$sites")"
rm -f docs/demo/.sites
echo "demo site removed"
