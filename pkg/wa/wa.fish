set -g WAHOO_MISSING_ARG   1
set -g WAHOO_UNKNOWN_OPT   2
set -g WAHOO_INVALID_ARG   3
set -g WAHOO_UNKNOWN_ERR   4

set -g WAHOO_VERSION "0.1.0"
set -g WAHOO_CONFIG  "$HOME/.config/wahoo"

function wa -d "Wahoo"
  function line; set_color -u; end
  function bold; set_color -o; end
  function em; set_color cyan; end
  function off; set_color normal; end

  if test (count $argv) -eq 0
    WAHOO::cli::help
    return 0
  end

  switch $argv[1]
    case "v" "ver" "version"
      WAHOO::cli::version

    case "h" "help"
      WAHOO::cli::help

    case "l" "li" "lis" "lst" "list"
      WAHOO::cli::list $WAHOO_PATH/pkg/*

    case "g" "ge" "get" "install"
      test (count $argv) -eq 1
        and WAHOO::cli::list $WAHOO_PATH/db/*.pkg .pkg
        or WAHOO::cli::get $argv[2..-1]

    case "t" "th" "thm" "themes"
      if test (count $argv) -ne 1
        echo "Wahoo: Too many arguments." 1^&2
        echo "Usage: $_ $argv[1]" 1^&2
        return $WAHOO_INVALID_ARG
      end
      WAHOO::cli::list $WAHOO_PATH/db/*.theme .theme

    case "u" "use"
      if test (count $argv) -eq 1
        WAHOO::util::list_themes
      else if test (count $argv) -eq 2
        WAHOO::cli::use $argv[2]
      else
        echo "Wahoo: Invalid number of arguments." 1^&2
        echo "Usage: $_ "(bold)"$argv[1]"(off)" [<theme name>]" 1^&2
        return $WAHOO_INVALID_ARG
      end

    case "R" "rm" "remove" "uninstall"
      if test (count $argv) -ne 2
        echo "Wahoo: Invalid number of arguments." 1^&2
        echo "Usage: $_ "(bold)"$argv[1]"(off)" <[package|theme] name>" 1^&2
        return $WAHOO_INVALID_ARG
      end
      WAHOO::cli::remove $argv[2..-1]

    case "U" "up" "upd" "update"
      pushd $WAHOO_PATH
      echo (bold)"Updating Wahoo..."(off)
      if WAHOO::cli::update
        echo (em)"Wahoo is up to date."(off)
      else
        echo (line)"Wahoo failed to update."(off)
        echo "Please open a new issue here → "(line)"git.io/wahoo-issues"(off)
      end
      popd
      reload

    case "s" "su" "sub" "submit"
      if test (count $argv) -ne 2
        echo "Wahoo: Argument missing." 1^&2
        echo "Usage: $_ "(bold)"$argv[1]"(off)" <package/theme name>" 1^&2
        return $WAHOO_MISSING_ARG
      end
      WAHOO::cli::submit $argv[2]

    case "*"
      echo (bold)"$argv[1]"(off)" option not recognized." 1^&2
      return $WAHOO_UNKNOWN_OPT
  end
end

function WAHOO::cli::version
  echo "Wahoo $WAHOO_VERSION"
end

function WAHOO::cli::help
  echo "\
  "(bold)"Wahoo"(off)"
    The Fishshell Framework

  "(bold)"Usage"(off)"
    wa "(set_color -u)"action"(set_color normal)" [ theme/package ]

  "(bold)"Actions"(off)"
    ("(em)"U"(off)")update  Update Wahoo.
       ("(em)"h"(off)")elp  Open Documentation.
        ("(em)"g"(off)")et  Install one or more themes/packages.
       ("(em)"l"(off)")ist  List installed packages.
        ("(em)"u"(off)")se  Apply a theme.
     ("(em)"t"(off)")hemes  List all themes.
    ("(em)"R"(off)")remove  Remove a theme or package.
     ("(em)"s"(off)")ubmit  Submit a package/theme to the registry.
    ("(em)"v"(off)")ersion  Show version.

  For more information visit → "(line)"git.io/wahoo-doc"(off)
end

function WAHOO::cli::use
  if not test -e $WAHOO_CUSTOM/themes/$argv[1]
    if not test -e $WAHOO_PATH/themes/$argv[1]
      set -l theme $WAHOO_PATH/db/$argv[1].theme
      if test -e $theme
        echo "Downloading "(bold)"$theme"(off)"..."
        git clone (cat $theme) \
          $WAHOO_PATH/themes/$argv[1] >/dev/null ^&1
          and echo (bold)"$theme"(off)" theme downloaded."
          or return $WAHOO_UNKNOWN_ERR
      else
        echo "Wahoo: `$argv[1]` is not a valid theme." 1^&2
        return $WAHOO_INVALID_ARG
      end
    end
  end
  WAHOO::util::apply_theme $argv[1]
end

function WAHOO::cli::list
  set -l path $argv[1]
  set -l ext ""
  set -q argv[2]; and set ext $argv[2]
  for item in (printf "%s\n" $path)
    basename $item "$ext"
  end | column
end

function WAHOO::cli::update
  set -l repo "upstream"
  test -z (git config --get remote.upstream.url); and set -l repo "origin"

  if WAHOO::git::repo_is_clean
    git pull $repo master >/dev/null ^&1
  else
    git stash
    if git pull --rebase $repo master
      git stash apply >/dev/null ^&1
    else
      WAHOO::util::sync_head # Like a boss
    end
  end
end

function WAHOO::cli::get
  for search in $argv
    if test -e $WAHOO_PATH/db/$search.theme
      set target themes/$search
    else if test -e $WAHOO_PATH/db/$search.pkg
      set target pkg/$search
    else
      echo "(bold)$search(normal) is not a valid package/theme." 1^&2
      continue
    end
    if test -e $WAHOO_PATH/$target
      pushd $WAHOO_PATH/$target
      WAHOO::util::sync_head
      popd
    else
      echo "Installing "(bold)"$search"(off)"..."
      git clone (cat $WAHOO_PATH/db/$search.*) \
        $WAHOO_PATH/$target >/dev/null ^&1
        and echo (bold)"$search"(off)" succesfully installed."
    end
  end
  reload
end

function WAHOO::cli::remove
  for pkg in $argv
    if not WAHOO::util::validate_package $pkg
      echo (bold)"$pkg"(off)" is not a valid package/theme name." 1^&2
      return $WAHOO_INVALID_ARG
    end

    if test -d $WAHOO_PATH/pkg/$pkg
      emit uninstall_$pkg
      rm -rf $WAHOO_PATH/pkg/$pkg
    else if test -d $WAHOO_PATH/themes/$pkg
      rm -rf $WAHOO_PATH/themes/$pkg
    end

    if test $status -eq 0
      echo (bold)"$pkg"(off)" succesfully removed."
    else
      echo (bold)"$pkg"(off)" could not be found." 1^&2
    end
  end
  reload
end

function WAHOO::cli::submit
  set -l name $argv[1]
  set -l ext ""
  switch $name
    case \*.pkg
      set ext .pkg
    case \*.theme
      case ext .theme
    case "*"
      echo "Missing extension "(bold)".pkg"(off)" or "(bold)".theme"(off) 1^&2
      return $WAHOO_INVALID_ARG
  end
  set name (basename $name $ext)

  set -l url (git config --get remote.origin.url)
  if test -z "$url"
    echo "Wahoo: `$name`'s remote URL not found." 1^&2
    echo "Try: git remote add <URL> or see Docs > Submitting" 1^&2
    return $WAHOO_INVALID_ARG
  end

  switch "$url"
    case \*bucaran/wahoo\*
      echo "Wahoo: "(bold)"$url"(off)" is not a valid package directory." 1^&2
      return $WAHOO_INVALID_ARG
  end

  set -l user (git config github.user)
  if test -z "$user"
    echo "Wahoo: GitHub user configuration not available." 1^&2
    echo "Try: "(bold)"git"(off)" config github.user "(line)"username"(off) 1^&2
    return $WAHOO_INVALID_ARG
  end

  if not WAHOO::util::validate_package $name
    echo "Wahoo: "(bold)"$pkg"(off)" is not a valid package/theme name." 1^&2
    return $WAHOO_INVALID_ARG
  end

  if test -e $WAHOO_PATH/db/$name$ext
    echo "Wahoo: "(bold)"$name"(off)" already exists in the registry." 1^&2
    echo "See: "(line)(cat $WAHOO_PATH/db/$name$ext)(off)" for more info." 1^&2
    return $WAHOO_INVALID_ARG
  end

  pushd $WAHOO_PATH

  if not git remote show remote >/dev/null ^&1
    WAHOO::util::fork_github_repo "$user" "bucaran/wahoo"
    git remote remove origin
    git remote add origin "https://github.com"/$user/wahoo
    git remote add remote "https://github.com"/bucaran/wahoo
  end

  git checkout -b add-$name

  echo "$url" > $WAHOO_PATH/db/$name$ext
  echo "$name added to the registry."

  git add -A
  git commit -m "Adding $name to registry."
  git push origin add-$name

  popd
  open "https://github.com"/$user/wahoo
end

function WAHOO::util::validate_package
  set -l pkg $argv[1]
  for default in wahoo colors
    if test (echo "$pkg" | tr "[:upper:]" "[:lower:]") = $default
      return 1
    end
  end
  switch $pkg
    case {a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}\*
      switch $pkg
        case "*/*" "* *" "*&*" "*\"*" "*!*" "*&*" "*%*" "*#*"
          return 1
      end
    case "*"
      return 1
  end
end

function WAHOO::util::fork_github_repo
  set -l repo $argv[1]
  set -l user $argv[2]

  curl -u "$user" --fail --silent \
    https://api.github.com/repos/$repo/forks \
    -d "{\"user\":\"$user\"}" >/dev/null
end

function WAHOO::util::sync_head
  set -l repo "origin"
  set -q argv[1]; and set repo $argv[1]

  git fetch origin master
  git reset --hard FETCH_HEAD
  git clean -df
end

function WAHOO::util::list_themes
  set -l theme (cat $WAHOO_CONFIG/theme)
  set -l regex "[[:<:]]($theme)[[:>:]]"
  test (uname) != "Darwin"; and set regex "\b($theme)\b"

  for theme in (printf "%s\n" $WAHOO_PATH/themes/*)
    basename $theme \
      | sed -E "s/$regex/"(em)"\1*"(off)"/"
  end | column
  set_color normal
end

function WAHOO::util::apply_theme
  echo $argv[1] > $WAHOO_CONFIG/theme
  reload
end

function WAHOO::git::repo_is_clean
  git diff-index --quiet HEAD --
end
