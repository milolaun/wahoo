function autoload -d "Autoload a function or completion path."
  for path in $argv
    if test -d "$path"
      set dest fish_function_path
      if test (basename "$path") = "completions"
        set dest fish_complete_path
      end
      if not contains "$path" $$dest
        set $dest "$path" $$dest
      end
    end
  end
end