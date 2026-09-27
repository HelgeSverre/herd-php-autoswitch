# Hidden setup for demo.tape. Creates a real, temporary Herd site (herd link) in a temp
# folder, and exposes this checkout at ~/.herd-php-autoswitch so the visible `source`
# line matches the README. docs/demo/cleanup.sh undoes all of it.
local repo=$PWD
local sites=$(mktemp -d)/Herd
mkdir -p "$sites/my-project/app/Models" "$sites/other-project"
(cd "$sites/my-project" && herd link >/dev/null 2>&1)
ln -sfn "$repo" ~/.herd-php-autoswitch
print -r -- "$sites" > "$repo/docs/demo/.sites"

export PATH="$HOME/Library/Application Support/Herd/bin:/usr/bin:/bin"
export CDPATH="$sites"
setopt interactivecomments cd_silent prompt_subst
# Show the temp folder as ~ so the prompt reads ~/Herd/my-project.
demo_root=${sites:h}
PROMPT='%F{magenta}~/${PWD#$demo_root/}%f %F{yellow}❯%f '
cd "$sites"
