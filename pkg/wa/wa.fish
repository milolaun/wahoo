set -g WAHOO_MISSING_ARG   1
set -g WAHOO_UNKNOWN_OPT   2
set -g WAHOO_INVALID_ARG   3
set -g WAHOO_UNKNOWN_ERR   4

set -g WAHOO_VERSION "0.1.0"
set -g WAHOO_CONFIG  "$HOME/.config/wahoo"

function wa -d "Wahoo"
  set -l github "https://github.com"
  set -l source "bucaran"

  set -l __  (set_color normal)
  set -l em  (set_color 00ffff)
  set -l b   (set_color -o)
  set -l u   (set_color -u)

  ################################ WAHOO::cli ################################

  function WAHOO::cli::version
    echo "Wahoo $WAHOO_VERSION"
    set -l latest (WAHOO::util::get_latest_version)
    test -z "$latest"; or echo $u"Latest"$__": v$em$latest$__"
  end

  function WAHOO::cli::help
    echo "\
    $b"Wahoo"$__
      The Fishshell Framework

    $b"Usage"$__
      wahoo $u"action"$__ [ theme/package ]

    $b"Actions"$__
         ("$em"U"$__")update  Update Wahoo.
            ("$em"h"$__")elp  Open Documentation.
             ("$em"g"$__")et  Install one or more themes/packages.
            ("$em"l"$__")ist  List installed packages.
             ("$em"u"$__")se  Apply a theme.
          ("$em"t"$__")hemes  List all themes.
         ("$em"R"$__")remove  Remove a theme or package.
          ("$em"s"$__")ubmit  Submit a package/theme to the registry.
         ("$em"v"$__")ersion  Show version.

    $b For more information visit → $u"git.io/wahoo-doc"$__"
  end

  function WAHOO::cli::use
    if not test -e $WAHOO_CUSTOM/themes/$argv[1]
      if not test -e $WAHOO_PATH/themes/$argv[1]
        set -l theme $WAHOO_PATH/db/$argv[1].theme
        if test -e $theme
          echo "Downloading "$b"$theme"$__"..."
          git clone (cat $theme) \
            $WAHOO_PATH/themes/$argv[1] >/dev/null ^&1
            and echo $b"$theme"$__" theme downloaded."
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
      if git pull --rebase $update master
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
        echo "$b$search$__ is not a valid package/theme." 1^&2
        continue
      end
      if test -e $WAHOO_PATH/$target
        pushd $WAHOO_PATH/$target
        WAHOO::util::sync_head
        popd
      else
        echo "Installing "$b"$search"$__"..."
        git clone (cat $WAHOO_PATH/db/$search.*) \
          $WAHOO_PATH/$target >/dev/null ^&1
          and echo $b"$search"$__" succesfully installed."
      end
    end
    reload
  end

  function WAHOO::cli::remove
    for pkg in $argv
      if not WAHOO::util::validate_package $pkg
        echo $b"$pkg"$__" is not a valid package/theme name." 1^&2
        return $WAHOO_INVALID_ARG
      end

      if test -d $WAHOO_PATH/pkg/$pkg
        emit uninstall_$pkg
        rm -rf $WAHOO_PATH/pkg/$pkg
      else if test -d $WAHOO_PATH/themes/$pkg
        rm -rf $WAHOO_PATH/themes/$pkg
      end

      if test $status -eq 0
        echo $b"$pkg"$__" succesfully removed."
      else
        echo $b"$pkg"$__" could not be found." 1^&2
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
        echo "Missing extension "$b".pkg"$__" or "$b".theme"$__ 1^&2
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
      case \*$source/wahoo\*
        echo "Wahoo: "$b"$url"$__" is not a valid package directory." 1^&2
        return $WAHOO_INVALID_ARG
    end

    set -l user (git config github.user)
    if test -z "$user"
      echo "Wahoo: GitHub user configuration not available." 1^&2
      echo "Try: "$b"git"$__" config github.user "$u"username"$__ 1^&2
      return $WAHOO_INVALID_ARG
    end

    if not WAHOO::util::validate_package $name
      echo "Wahoo: "$b"$pkg"$__" is not a valid package/theme name." 1^&2
      return $WAHOO_INVALID_ARG
    end

    if test -e $WAHOO_PATH/db/$name$ext
      echo "Wahoo: "$b"$name"$__" already exists in the registry." 1^&2
      echo "See: "$u(cat $WAHOO_PATH/db/$name$ext)$__" for more info." 1^&2
      return $WAHOO_INVALID_ARG
    end

    pushd $WAHOO_PATH

    if not git remote show remote >/dev/null ^&1
      WAHOO::util::fork_github_repo "$user" "$source/wahoo"
      git remote remove origin
      git remote add origin $github/$user/wahoo
      git remote add remote $github/$source/wahoo
    end

    git checkout -b add-$name

    echo "$url" > $WAHOO_PATH/db/$name$ext
    echo "$name added to the registry."

    git add -A
    git commit -m "Adding $name to registry."
    git push origin add-$name

    popd
    open $github/$user/wahoo
  end

  ############################### WAHOO::util ################################

  function WAHOO::util::validate_package
    set -l pkg $argv[1]
    if test (echo "$pkg" | tr "[:upper:]" "[:lower:]") != "wahoo"
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
  end

  function WAHOO::util::fork_github_repo
    set -l repo $argv[1]
    set -l user $argv[2]

    curl -u "$user" --fail --silent \
      https://api.github.com/repos/$repo/forks \
      -d "{\"user\":\"$user\"}" >/dev/null
  end

  function WAHOO::util::get_latest_version
    set -l ver (git ls-remote --tags $github/$source/wahoo | tail -1 \
    | sed -n 's/.*refs\/tags\/v//p' | sed -n 's/\^{}//p') >/dev/null ^&1
    switch "$ver"
      case {0,1,2,3,4,5,6,7,8,9}\*{0,1,2,3,4,5,6,7,8,9}\*
        echo $ver
    end
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
        | sed -E "s/$regex/"$em"\1*"$__"/"
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

  ################################## Wahoo ##################################

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
        echo "Usage: $_ "$b"$argv[1]"$__" [<theme name>]" 1^&2
        return $WAHOO_INVALID_ARG
      end

    case "R" "rm" "remove" "uninstall"
      if test (count $argv) -ne 2
        echo "Wahoo: Invalid number of arguments." 1^&2
        echo "Usage: $_ "$b"$argv[1]"$__" <[package|theme] name>" 1^&2
        return $WAHOO_INVALID_ARG
      end
      WAHOO::cli::remove $argv[2..-1]

    case "U" "up" "upd" "update"
      pushd $WAHOO_PATH
      echo $b"Updating Wahoo..."$__
      if WAHOO::cli::update
        echo $em"Wahoo is up to date."$__
      else
        echo $u"Wahoo failed to update."$__
        echo "Please open a new issue here → "$u"git.io/wahoo-issues"$__
      end
      popd
      reload

    case "s" "su" "sub" "submit"
      if test (count $argv) -ne 2
        echo "Wahoo: Argument missing." 1^&2
        echo "Usage: $_ "$b"$argv[1]"$__" <package/theme name>" 1^&2
        return $WAHOO_MISSING_ARG
      end
      WAHOO::cli::submit $argv[2]

    case "*"
      echo $b"$argv[1]"$__" option not recognized." 1^&2
      return $WAHOO_UNKNOWN_OPT
  end
end
