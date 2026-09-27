#!/bin/sh
# Checks that the Nushell hook fires in a real REPL (env_change hooks only run there).
# Drives `nu` with expect, answering the line editor's cursor-position query.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
home=$(mktemp -d)
sh "$root/tests/mock-herd.sh" "$home"

cat > "$home/repl.exp" <<EOF
set timeout 30
spawn env -i HOME=$home TERM=xterm-256color "PATH=$home/Library/Application Support/Herd/bin:$PATH" nu -n -e "source '$root/herd-php-autoswitch.nu'; def r \[label\] { print \\\$'STEP (\\\$label)|(^php)' }"
expect_background -re "\033\\\\\[6n" { send "\033\[1;1R" }
proc cmd {line} { sleep 1.5; send "\$line\r" }
cmd "r start-in-site"
cmd "cd app/Models"
cmd "r subdirectory"
cmd "cd ~/Herd/legacy"
cmd "r legacy"
cmd "cd ~/Herd/other-project"
cmd "r other-project"
cmd "cd ~"
cmd "r home"
cmd "cd ~/Herd/my-project"
cmd "r re-enter"
cmd "cd ~; r one-liner"
cmd "r after-prompt"
cmd "exit"
sleep 2
EOF

actual=$(cd "$home/Herd/my-project" && expect "$home/repl.exp" 2>&1 |
  tr -d '\r' | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' | grep -aoE 'STEP [a-z-]+\|[0-9.]+' | awk '!seen[$0]++')
# The one-liner still sees 8.3: env_change hooks run when the next prompt is drawn.
expected='STEP start-in-site|8.3.0
STEP subdirectory|8.3.0
STEP legacy|8.2.0
STEP other-project|8.4.0
STEP home|8.4.0
STEP re-enter|8.3.0
STEP one-liner|8.3.0
STEP after-prompt|8.4.0'
rm -rf "$home"

echo "nushell REPL ($(nu --version))"
if [ "$actual" = "$expected" ]; then
  printf '%s\n' "$actual" | sed 's/^STEP /  ok   /'
  echo "all passed"
else
  echo "  FAIL expected:"; printf '%s\n' "$expected"
  echo "  got:"; printf '%s\n' "$actual"
  exit 1
fi
