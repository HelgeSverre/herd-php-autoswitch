# Render from the repo root: vhs docs/demo/demo.tape   (needs Laravel Herd with PHP 8.3 and 8.4)
Output docs/demo.gif

Set Shell "zsh"
Set FontSize 22
Set Width 1200
Set Height 580
Set Padding 32
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms

Hide
Type "source docs/demo/setup.zsh && clear"
Enter
Show

Type "# my-project is pinned with: herd isolate 8.3"
Enter
Sleep 400ms
Type "cd ~/Herd/my-project"
Enter
Type "php -v | head -1"
Enter
Sleep 1.5s

Type "# composer and artisan use the same version"
Enter
Sleep 400ms
Type "composer --version 2>&1 | grep -o 'PHP version [0-9.]*'"
Enter
Sleep 1.5s

Type "# subfolders too"
Enter
Sleep 400ms
Type "cd app/Models && php -v | head -1"
Enter
Sleep 1.5s

Type "# leave the site: back to Herd's default"
Enter
Sleep 400ms
Type "cd ~/Herd/other-project"
Enter
Type "php -v | head -1"
Enter
Sleep 3s
