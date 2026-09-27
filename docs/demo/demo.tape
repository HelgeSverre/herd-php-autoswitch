# Render from the repo root, then clean up:
#   vhs docs/demo/demo.tape && sh docs/demo/cleanup.sh
# Needs Laravel Herd with PHP 8.3 and 8.4 (global default). Creates a temporary Herd site.
Output docs/demo.gif

Set Shell "zsh"
Set FontSize 22
Set Width 1440
Set Height 600
Set Padding 32
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms

Hide
Type "source docs/demo/setup.zsh && clear"
Enter
Sleep 2s
Show

Type "cd my-project"
Enter
Sleep 600ms

Type "herd isolate 8.3"
Enter
Sleep 3s

Type "php -v | head -1"
Enter
Sleep 2.5s

Type "source ~/.herd-php-autoswitch/herd-php-autoswitch.plugin.zsh"
Enter
Sleep 800ms

Type "php -v | head -1"
Enter
Sleep 2.5s

Type "composer -V 2>&1 | grep -o 'PHP version [0-9.]*'"
Enter
Sleep 2s

Type "cd app/Models && php -v | head -1"
Enter
Sleep 2s

Type "cd other-project && php -v | head -1"
Enter
Sleep 4s
