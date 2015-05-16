function _git_branch_name
  echo (command git symbolic-ref HEAD ^/dev/null | sed -e 's|^refs/heads/||')
end

function fish_prompt
  set -l blue (set_color -o blue)
  set -l green (set_color -o green)

  test (_git_branch_name)
    and set color $blue
    or set color $green

  echo -n -s "$color>> "
end