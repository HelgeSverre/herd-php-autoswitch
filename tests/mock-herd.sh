#!/bin/sh
# Builds a fake Laravel Herd install in the home directory given as $1:
# the macOS layout (Library/Application Support/Herd) and the Windows layout (.config/herd).
# Fake PHP binaries print their version; composer runs whichever `php` is first on PATH.
#
# Sites, as Herd sees them:
#   ~/Herd is a parked path, so each folder directly in it is a site named after the folder.
#   ~/Code/worktree-folder is linked as "linked-app" (link name differs from the folder name).
#   ~/elsewhere/my-project is NOT a site; it only shares a name with one.
set -eu
home=$1

fake_php() { # $1 = file, $2 = version
  printf '#!/bin/sh\necho %s\n' "$2" > "$1"
  chmod +x "$1"
}

site_configs() { # $1 = valet dir, $2 = file suffix (.conf on Windows)
  mkdir -p "$1/Nginx" "$1/Sites"
  printf '# ISOLATED_PHP_VERSION=8.3\nserver {}\n' > "$1/Nginx/my-project.test$2"
  printf '# ISOLATED_PHP_VERSION=8.2\nserver {}\n' > "$1/Nginx/legacy.test$2"
  printf 'server {}\n' > "$1/Nginx/other-project.test$2"
  # A site that shares a name with a subfolder of my-project.
  printf '# ISOLATED_PHP_VERSION=8.2\nserver {}\n' > "$1/Nginx/docs.test$2"
  # Isolated to a version this Herd does not have.
  printf '# ISOLATED_PHP_VERSION=8.1\nserver {}\n' > "$1/Nginx/old-app.test$2"
  printf '# ISOLATED_PHP_VERSION=8.2\nserver {}\n' > "$1/Nginx/linked-app.test$2"
  ln -s "$home/Code/worktree-folder" "$1/Sites/linked-app"
  printf '{\n    "tld": "test",\n    "loopback": "127.0.0.1",\n    "paths": [\n        "%s",\n        "%s/"\n    ]\n}\n' \
    "$1/Sites" "$home/Herd" > "$1/config.json"
}

# macOS
mac="$home/Library/Application Support/Herd"
mkdir -p "$mac/bin"
fake_php "$mac/bin/php" 8.4.0
for v in 82 83 84; do fake_php "$mac/bin/php$v" "${v%?}.${v#?}.0"; done
printf '#!/usr/bin/env php\n' > "$mac/bin/composer"
chmod +x "$mac/bin/composer"
site_configs "$mac/config/valet" ""

# Windows: one folder per version holding php (php.bat on Windows)
win="$home/.config/herd"
mkdir -p "$win/bin"
fake_php "$win/bin/php" 8.4.0
printf '@echo 8.4.0\r\n' > "$win/bin/php.bat"
for v in 82 83 84; do
  mkdir -p "$win/bin/php$v"
  fake_php "$win/bin/php$v/php" "${v%?}.${v#?}.0"
  printf '@echo %s\r\n' "${v%?}.${v#?}.0" > "$win/bin/php$v/php.bat"
done
printf '#!/bin/sh\nexec php "$@"\n' > "$win/bin/composer"
chmod +x "$win/bin/composer"
printf '@php %%*\r\n' > "$win/bin/composer.bat"
site_configs "$win/config/valet" ".conf"

mkdir -p "$home/Herd/my-project/app/Models" "$home/Herd/my-project/docs" "$home/Herd/legacy" \
  "$home/Herd/other-project" "$home/Herd/old-app" "$home/Code/worktree-folder/src" \
  "$home/elsewhere/my-project"
