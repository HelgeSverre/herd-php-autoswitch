# Builds a throwaway home with one isolated Herd site, using this machine's real Herd
# PHP binaries, and loads the plugin from this checkout. Sourced by demo.tape.
local repo=$PWD herd="$HOME/Library/Application Support/Herd"
local demo=$(mktemp -d)/demo
local bin="$demo/Library/Application Support/Herd/bin" nginx="$demo/Library/Application Support/Herd/config/valet/Nginx"
mkdir -p "$bin" "$nginx" "$demo/Herd/my-project/app/Models" "$demo/Herd/other-project"
ln -s "$herd/bin/php84" "$bin/php"
ln -s "$herd/bin/php83" "$bin/php83"
ln -s "$herd/bin/php84" "$bin/php84"
ln -s "$herd/bin/composer" "$bin/composer"
print '{ "tld": "test" }' > "$nginx/../config.json"
print '# ISOLATED_PHP_VERSION=8.3' > "$nginx/my-project.test"

export HOME=$demo
export PATH="$bin:/usr/bin:/bin"
setopt interactivecomments
PROMPT='%F{magenta}%~%f %F{yellow}❯%f '
source "$repo/herd-php-autoswitch.plugin.zsh"
cd ~
