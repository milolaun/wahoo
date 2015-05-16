<p align="center">
<a href="https://github.com/bucaran/wahoo/blob/master/README.md">
<img width="20%" src="https://cloud.githubusercontent.com/assets/8317250/7772540/c6929db6-00d9-11e5-86bc-4f65533243e9.png">
</a>
</p>

<br>
<p align="center">
<b><a href="#bootstrap-process">Bootstrap</a></b>
|
<b><a href="#core-library">Core</a></b>
|
<b><a href="#packages">Packages</a></b>
|
<b><a href="#submitting">Submitting</a></b>
|
<b><a href="#package-directory-structure">Structure</a></b>
|
<b><a href="#initialization">Initialization</a></b>
|
<b><a href="#uninstall">Uninstall</a></b>
</p>
<br>


## Bootstrap Process

Wahoo's bootstrap script installs `git`, `fish` if not already installed, changes your default shell to `fish` and modifies `$HOME/.config/fish/config.fish` to load the Wahoo `init.fish` script at the start of a shell session.

It also extends the `fish_function_path` to autoload Wahoo's core library under `$WAHOO_PATH/lib` and the `$WAHOO_PATH/pkg` directory.

## Core library

The core library is a minimum set of basic utility functions that you can use in your own packages.

### `autoload`

Use to modify the `$fish_function_path` and autoload functions and/or completions easily.

```fish
autoload "mypkg/utils" "mypkg/core" "mypkg/lib/completions"
```

### `reload`

Use to `reload` Wahoo inmediately.

## Packages

Every directory inside `$WAHOO_PATH/pkg` is a _package_. Since only one theme can be activated at a time, themes are kept in a different directory under `$WAHOO_PATH/themes`, but the loading mechanism is the same for all plugins, libraries, themes, etc.

### Submitting

Use `wahoo submit <package/theme name>` from the package's directory or by hand, add a plain text file to `$WAHOO_PATH/db/<mpkg>[.pkg|.theme]` with the URL to your repository and submit a [pull request](https://github.com/bucaran/wahoo/pulls).

_Directory Structure_
```
wahoo/
  db/
    mypkg.pkg
```
_File Contents_
```
https://github.com/$USER/wahoo-mypkg
```

### Package Directory Structure

A package can be as simple as a `mypkg/mypkg.fish` file exposing only a `mypkg` function, or several `function.fish` files, a `README` file, a `completions/mypkg.fish` file with fish [tab-completions](http://fishshell.com/docs/current/commands.html#complete), etc.

+ Example:

```
mypkg/
  README.md
  mypkg.fish
  completions/mypkg.fish
```

### Initialization

Wahoo loads each `$WAHOO_PATH/<pkg>.fish` on startup and [emit](http://fishshell.com/docs/current/commands.html#emit) `init_<pkg>` events to subscribers with the full path to the package.

```fish
function init -a path --on-event init_mypkg
end

function mypkg -d "My package"
end
```

Use the `init` event set up your package environment, load resources, autoload functions, etc. Writing an event handler for the `init` event is optional.


### Uninstall

Wahoo emits `uninstall_<pkg>` events when a package is removed using `wahoo remove <pkg>`. Subscribers can use the event to clean up custom resources, etc.

```fish
function uninstall --on-event uninstall_pkg
end
```