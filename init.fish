# Run at the start of the shell.

set -g WAHOO_CUSTOM (cat $HOME/.config/wahoo/custom)

set -l user_function_path $fish_function_path[1]
set fish_function_path[1] $WAHOO_PATH/lib

set -l theme     (cat $HOME/.config/wahoo/theme)
set -l packages  $WAHOO_PATH/pkg/*

test -d $WAHOO_CUSTOM
  and set packages $packages $WAHOO_CUSTOM/*

test -d $WAHOO_CUSTOM/$theme
  and set theme $WAHOO_CUSTOM/$theme
  or set theme $WAHOO_PATH/themes/$theme

for path in $packages $theme
  autoload $path $path/completions
  source $path/(basename $path).fish ^/dev/null
    and emit init_(basename $path) $path
end

autoload "$user_function_path"
