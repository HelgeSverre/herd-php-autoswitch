#!/bin/sh
# Runs the zsh, bash and fish hooks against a fake Herd install.
# Usage: tests/run.sh [zsh|bash|fish ...]   (default: every shell that is installed)
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
shells=${*:-zsh bash fish}
failures=0

# label, directory relative to $HOME, expected PHP version
steps='my-project Herd/my-project 8.3.0
subdirectory Herd/my-project/app/Models 8.3.0
docs-subfolder Herd/my-project/docs 8.3.0
legacy Herd/legacy 8.2.0
other-project Herd/other-project 8.4.0
linked-site Code/worktree-folder 8.2.0
linked-subfolder Code/worktree-folder/src 8.2.0
same-name-not-a-site elsewhere/my-project 8.4.0
missing-version Herd/old-app 8.4.0
elsewhere elsewhere 8.4.0
home . 8.4.0
re-enter Herd/my-project 8.3.0'

# Each shell prints "label|php|composer|shims" per step; this compares them.
check() { # $1 = shell name, stdin = output lines; returns 1 if any step failed
  failed=0
  while IFS='|' read -r label php composer shims; do
    expected=$(printf '%s\n' "$steps" | awk -v l="$label" '$1 == l { print $3 }')
    case $label in
      status) expected=1 ;;
      uninstalled) expected=8.4.0 ;;
    esac
    if [ "$php" = "$expected" ] && { [ -z "$composer" ] || [ "$composer" = "$expected" ]; } && [ "${shims:-0}" -le 1 ]; then
      echo "  ok   $1 $label: php $php${composer:+, composer $composer}"
    else
      echo "  FAIL $1 $label: php '$php' composer '$composer' shims '$shims' (expected $expected, at most 1 shim)"
      failed=1
    fi
  done
  return $failed
}

cd_lines() { # $1 = line to append after each cd
  printf '%s\n' "$steps" | while read -r label dir _; do
    printf 'cd "$HOME/%s"\n%s %s\n' "$dir" "$1" "$label"
  done
}

for shell in $shells; do
  if ! command -v "$shell" >/dev/null 2>&1; then
    echo "skip $shell (not installed)"
    continue
  fi
  home=$(mktemp -d)
  sh "$root/tests/mock-herd.sh" "$home"
  herd_bin="$home/Library/Application Support/Herd/bin"
  echo "$shell ($("$shell" --version 2>&1 | head -1))"

  case $shell in
    zsh)
      {
        echo "source '$root/herd-php-autoswitch.plugin.zsh'"
        echo 'r() { print -r -- "$1|$(php)|$(composer)|${#${(@M)path:#*herd-php-autoswitch*}}" }'
        cd_lines r
      } > "$home/test.zsh"
      HOME=$home PATH="$herd_bin:$PATH" zsh -f "$home/test.zsh" 2> "$home/stderr" | check zsh || failures=$((failures + 1))
      ;;
    bash)
      # PROMPT_COMMAND only runs in interactive shells, so feed the script to `bash -i`.
      # Each check runs on its own line, after the prompt that follows the cd.
      {
        echo "source '$root/herd-php-autoswitch.bash'"
        echo 'r() { local n=0 p; local IFS=:; for p in $PATH; do [[ $p == *herd-php-autoswitch* ]] && n=$((n+1)); done; echo "$1|$(php)|$(composer)|$n"; }'
        cd_lines r
        # A prompt hook added after ours must still see the exit status of the last command.
        echo 'PROMPT_COMMAND="$PROMPT_COMMAND;__seen_status=\$?"'
        echo 'cd "$HOME/Herd/legacy"; false'
        echo 'echo "status|$__seen_status||"'
      } > "$home/test.bash"
      HOME=$home PATH="$herd_bin:$PATH" bash --norc --noprofile -i < "$home/test.bash" 2> "$home/stderr" | check bash || failures=$((failures + 1))
      ;;
    fish)
      {
        echo "source '$root/conf.d/herd-php-autoswitch.fish'"
        echo 'function r; echo "$argv[1]|"(php)"|"(composer)"|"(count (string match -- "*herd-php-autoswitch*" $PATH)); end'
        cd_lines r
        echo 'emit herd-php-autoswitch_uninstall'
        echo 'r uninstalled'
        echo 'functions -q __herd_autoswitch_apply; and echo "uninstalled|handler still defined||"'
      } > "$home/test.fish"
      HOME=$home PATH="$herd_bin:$PATH" fish --no-config "$home/test.fish" 2> "$home/stderr" | check fish || failures=$((failures + 1))
      ;;
  esac
  warnings=$(grep -c 'PHP 8.1 is not installed' "$home/stderr" 2>/dev/null)
  if [ "$warnings" = 1 ]; then
    echo "  ok   $shell warns once about the missing PHP 8.1"
  else
    echo "  FAIL $shell printed the missing-version warning $warnings times (expected 1)"
    failures=$((failures + 1))
  fi
  rm -rf "$home"
done

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
