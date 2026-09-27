<img src="docs/banner.webp" alt="Illustration of a developer herding purple PHP elephants tagged 8.3, 8.4 and 8.2 past a terminal showing cd my-project and php 8.3, titled HERD-PHP-AUTOSWITCH" width="100%">

# Herd PHP Autoswitch

[![tests](https://github.com/HelgeSverre/herd-php-autoswitch/actions/workflows/tests.yml/badge.svg)](https://github.com/HelgeSverre/herd-php-autoswitch/actions/workflows/tests.yml)
![zsh](https://img.shields.io/badge/zsh-F15A24?logo=zsh&logoColor=white)
![bash](https://img.shields.io/badge/bash-4EAA25?logo=gnubash&logoColor=white)
![fish](https://img.shields.io/badge/fish-34C534?logo=fishshell&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5391FE)
![Nushell](https://img.shields.io/badge/Nushell-4E9A06?logo=nushell&logoColor=white)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

**Your terminal now uses the PHP version you set with `herd isolate`.** When you `cd` into an isolated site, `php`,
`composer` and `artisan` switch to that version, in subfolders too. When you leave, they switch back to Herd's default.
Works in zsh, bash, fish, PowerShell and Nushell, on macOS and Windows.

```bash
# my-project is isolated to PHP 8.3 (herd isolate 8.3)
cd ~/Herd/my-project
php -v                  # PHP 8.3.33

# composer and artisan run on the same version
composer --version      # ... PHP version 8.3.33

# outside an isolated site: Herd's global default
cd ~
php -v                  # PHP 8.4.25
```

Herd's own `herd php` and `herd composer` only respect isolation from the site's root directory, and only with the
`herd` prefix.

## Install

You need [Laravel Herd](https://herd.laravel.com) on macOS or Windows and a site isolated with `herd isolate <version>`.
Open a new terminal after installing.

### zsh (macOS)

- [antidote](https://antidote.sh): add `HelgeSverre/herd-php-autoswitch` to `~/.zsh_plugins.txt`
- [zinit](https://github.com/zdharma-continuum/zinit): `zinit light HelgeSverre/herd-php-autoswitch`
- [zap](https://www.zapzsh.com): `plug "HelgeSverre/herd-php-autoswitch"`
- [sheldon](https://sheldon.cli.rs): `sheldon add herd-php-autoswitch --github HelgeSverre/herd-php-autoswitch`

[oh-my-zsh](https://ohmyz.sh): clone into your custom plugins, then add `herd-php-autoswitch` to `plugins=(...)` in
`~/.zshrc`:

```bash
git clone https://github.com/HelgeSverre/herd-php-autoswitch ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/herd-php-autoswitch
```

Without a plugin manager:

```bash
git clone https://github.com/HelgeSverre/herd-php-autoswitch ~/.herd-php-autoswitch
echo 'source ~/.herd-php-autoswitch/herd-php-autoswitch.plugin.zsh' >> ~/.zshrc
```

Load order in `~/.zshrc` doesn't matter; the plugin applies again at the first prompt.

### bash (macOS, 3.2+)

```bash
git clone https://github.com/HelgeSverre/herd-php-autoswitch ~/.herd-php-autoswitch
echo 'source ~/.herd-php-autoswitch/herd-php-autoswitch.bash' >> ~/.bashrc
```

- Terminal.app starts login shells, which read `~/.bash_profile`; make sure it sources `~/.bashrc`.
- bash has no directory-change hook, so the switch happens at the next prompt. In `cd other-project && php -v`, `php`
  is still the previous directory's version.

### fish (macOS, 3.5+)

With [Fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install HelgeSverre/herd-php-autoswitch
```

Without Fisher, copy `conf.d/herd-php-autoswitch.fish` to `~/.config/fish/conf.d/`.

### PowerShell (Windows, 5.1+)

```powershell
git clone https://github.com/HelgeSverre/herd-php-autoswitch "$HOME\herd-php-autoswitch"
if (-not (Test-Path $PROFILE.CurrentUserAllHosts)) { New-Item -ItemType File -Path $PROFILE.CurrentUserAllHosts -Force }
Add-Content $PROFILE.CurrentUserAllHosts 'Import-Module "$HOME\herd-php-autoswitch\HerdPhpAutoswitch"'
```

- PowerShell 7 switches after every `cd`, `Set-Location`, `Push-Location` and `Pop-Location`.
- Windows PowerShell 5.1 has no such hook, so it switches at the next prompt, keeping your existing prompt
  (oh-my-posh, starship). 5.1 blocks profile scripts by default; allow them once with
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
- PowerShell 7 and 5.1 have separate profiles. Add the line to each one you use.

### Nushell (macOS and Windows)

```nu
git clone https://github.com/HelgeSverre/herd-php-autoswitch ~/.herd-php-autoswitch
```

Add this line to your config (`config nu` opens it):

```nu
source ~/.herd-php-autoswitch/herd-php-autoswitch.nu
```

[Nushell](https://www.nushell.sh) runs the hook at the next prompt, so a `cd` and a `php` on the same line use the
previous directory's version.

## Verify

```bash
cd ~/Herd/my-project
php -v                                          # the isolated version
composer --version 2>&1 | grep 'PHP version'    # same version
which php                                       # ~/.cache/herd-php-autoswitch/83/php
```

On Windows, `(Get-Command php).Source` shows `...\.config\herd\bin\php83\php.exe`.

## How it works

Herd records isolation on the first line of the site's nginx config, for example
`~/Library/Application Support/Herd/config/valet/Nginx/my-project.test`:

```
# ISOLATED_PHP_VERSION=8.3
```

`herd php` and `herd which-php` read the same line. On every directory change the hook:

1. walks up to the nearest folder with a matching config (`<folder name>.<tld>`, TLD from Herd's `config.json`),
2. reads the version from that line,
3. puts that version first on `PATH`:
   - macOS: `~/.cache/herd-php-autoswitch/83`, a folder with one symlink, `php`, to Herd's `php83`
   - Windows: Herd's own `bin\php83` folder

`composer`, `php artisan` and `vendor/bin` scripts run on the first `php` on `PATH`, so they follow. Each switch reads
one file (under 2 ms); the `herd` binary is never called.

## Compatibility

- Tested with Laravel Herd 1.30 on macOS: zsh 5.9, bash 3.2 and 5.3, fish 4.9, PowerShell 7.6, Nushell 0.115.
- Works alongside [direnv](https://direnv.net) and [mise](https://mise.jdx.dev) in zsh, bash and fish, in either load
  order (tested with direnv 2.37 and mise 2026.9).
- CI runs every shell against a fake Herd install on macOS, Ubuntu and Windows, including Windows PowerShell 5.1.
- Herd for Windows paths come from Herd's Windows documentation; CI uses a replica of that layout.

## Limitations

- Sites are found by folder name, so a site linked under another name (`herd link other-name`) is not detected.
- A subfolder named like another secured or isolated site (`docs` when `docs.test` exists) matches that site.
- Only `herd isolate` is read; PHP versions in `.valetrc` or `.valetphprc` are ignored.
- It changes your shell only. To make Composer resolve for your production PHP everywhere, also run
  `composer config platform.php 8.3.30`.

After `herd isolate` or `herd unisolate` inside a site, refresh with:

- zsh, fish, Nushell: `cd .`
- bash: `unset _herd_autoswitch_pwd`
- PowerShell: `Update-HerdPhpAutoswitch` (or `cd .`)

## Uninstall

- zsh, bash, Nushell: remove the `source` line or plugin entry, and the cloned folder.
- fish: `fisher remove HelgeSverre/herd-php-autoswitch`.
- PowerShell: remove the `Import-Module` line from your profile, and the cloned folder.
- macOS: `rm -rf ~/.cache/herd-php-autoswitch`.

## Development

The tests build a fake Herd install in a temporary folder, so they run without Herd:

```bash
sh tests/run.sh                        # zsh, bash, fish (whichever are installed)
pwsh -NoProfile -File tests/run.ps1    # PowerShell module
nu -n tests/run.nu                     # Nushell
sh tests/nu-repl.sh                    # Nushell REPL, needs expect
```

## License

MIT. See [LICENSE](LICENSE).
