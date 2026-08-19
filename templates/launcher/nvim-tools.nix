# `setup-nvim` — pick a Neovim setup, or add the launcher's integrations to one you
# already have. Nothing installs Neovim configuration automatically: the choice of
# distro is the user's, and an existing ~/.config/nvim is never touched unless you
# say so in as many words.
#
#   setup-nvim                          interactive menu
#   setup-nvim --distro astronvim       non-interactive
#   setup-nvim --distro astronvim --appname astronvim
#                                       install side by side, launch with
#                                       NVIM_APPNAME=astronvim nvim
#   setup-nvim --integrations-only      just clipboard + wrap (+ theme where supported)
#
# What "integrations" means: OSC 52 clipboard so yanks reach the Android clipboard,
# always-on line wrap for a phone-width screen, and — on AstroNvim and NvChad — a
# colourscheme generated from the launcher's wallpaper palette that retints live when
# the wallpaper changes.
{ pkgs }:
let
  # Shipped Lua, copied into the chosen config so it survives without this flake.
  materialPalette = ./config/nvim/material_palette.lua;
  integrations = ./config/nvim/integrations.lua;
  themeMaterial = ./config/nvim/theme-material.lua;
  astroColorsMaterial = ./config/nvim/astro-colors-material.lua;
  astroPluginMaterial = ./config/nvim/astro-plugin-material.lua;

  # These scripts run under whatever shell the user happens to be in, and the base
  # environment ships neither coreutils nor grep, so an unqualified `grep` or `tr`
  # is simply absent right after a first switch. Put what they need on PATH instead
  # of absolutising every call, and keep the inherited PATH behind it so `nix` and
  # `nix-on-droid` still resolve.
  toolPath = ''
    export PATH="${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.gnused ]}:$PATH"
  '';

  git = "${pkgs.git}/bin/git";
  sed = "${pkgs.gnused}/bin/sed";
in
[
  (pkgs.writeShellScriptBin "setup-nvim" ''
    set -eu
    ${toolPath}

    distro=""
    appname="nvim"
    integrations_only=0
    assume_yes=0

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --distro) distro="''${2:-}"; shift 2 ;;
        --appname) appname="''${2:-}"; shift 2 ;;
        --integrations-only) integrations_only=1; shift ;;
        --yes|-y) assume_yes=1; shift ;;
        -h|--help)
          echo "usage: setup-nvim [--distro astronvim|nvchad|lazyvim|kickstart|stock]"
          echo "                  [--appname NAME] [--integrations-only] [--yes]"
          exit 0 ;;
        *) echo "setup-nvim: unknown option '$1'" >&2; exit 2 ;;
      esac
    done

    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
    target="$config_home/$appname"
    data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/$appname"

    # --- integrations, shared by every branch -------------------------------

    # Copy-once: these are yours to edit afterwards, like conf.d/personal.fish.
    install_integrations() {
      mkdir -p "$target/lua/launcher"
      for pair in "${materialPalette}:material_palette.lua" "${integrations}:integrations.lua"; do
        src="''${pair%%:*}"; name="''${pair##*:}"
        if [ ! -e "$target/lua/launcher/$name" ]; then
          cp "$src" "$target/lua/launcher/$name"
          chmod u+w "$target/lua/launcher/$name"
        fi
      done
    }

    # Append the require to whichever file the chosen config loads for user options.
    hook_integrations() {
      hook_file="$1"
      mkdir -p "$(dirname "$hook_file")"
      [ -e "$hook_file" ] || : > "$hook_file"
      if ! grep -q 'launcher.integrations' "$hook_file"; then
        printf '\n-- Termux Launcher: OSC 52 clipboard, line wrap, wallpaper theme.\nrequire "launcher.integrations"\n' >> "$hook_file"
      fi
    }

    # NvChad only: base46 themes are Lua tables, so the palette can drive one.
    install_material_theme() {
      mkdir -p "$target/lua/themes"
      [ -e "$target/lua/themes/material.lua" ] || cp "${themeMaterial}" "$target/lua/themes/material.lua"
      chmod u+w "$target/lua/themes/material.lua"
      if [ -e "$target/lua/chadrc.lua" ]; then
        ${sed} -i 's|theme = "onedark"|theme = "material"|' "$target/lua/chadrc.lua"
      fi
      # base46 compiles highlights to a cache; a stale cache silently keeps the old
      # theme, which looks exactly like the new theme failing to load.
      rm -rf "$data_dir/base46"
    }

    # --- distro installers --------------------------------------------------

    clone() {
      ${git} clone --depth=1 "$1" "$target"
      rm -rf "$target/.git"
    }

    # AstroNvim has no base46, so the palette drives base16-nvim through a
    # colors/material.lua, plus explicit chrome, heirline mode and git-sign groups:
    # AstroNvim resolves its statusline colours from highlight groups, and anything
    # left undefined silently falls back to its stock theme.
    install_astronvim() {
      clone https://github.com/AstroNvim/template
      install_integrations
      mkdir -p "$target/colors" "$target/lua/plugins"
      [ -e "$target/colors/material.lua" ] || cp "${astroColorsMaterial}" "$target/colors/material.lua"
      [ -e "$target/lua/plugins/material.lua" ] || cp "${astroPluginMaterial}" "$target/lua/plugins/material.lua"
      chmod u+w "$target/colors/material.lua" "$target/lua/plugins/material.lua"
      hook_integrations "$target/init.lua"
      echo "AstroNvim installed. Keybind hints: <leader> shows the which-key menu."
      echo "Colourscheme follows your wallpaper; :MaterialThemeInfo shows how it was built,"
      echo "and :MaterialTransparent toggles a transparent background."
    }

    install_nvchad() {
      clone https://github.com/NvChad/starter
      install_integrations
      install_material_theme
      hook_integrations "$target/lua/options.lua"
      echo "NvChad installed. Cheatsheet: <leader>ch   Theme picker: <leader>th"
      echo "Colourscheme follows your wallpaper; :MaterialThemeInfo shows how it was built."
    }

    install_lazyvim() {
      clone https://github.com/LazyVim/starter
      # Nothing in the starter needs luarocks -- lazy.nvim says so in its own health
      # check -- but with rocks left on it still tries to build hererocks on the
      # phone and reports an error until it does.
      ${sed} -i \
        's|^  install = { colorscheme|  rocks = { enabled = false },\n  install = { colorscheme|' \
        "$target/lua/config/lazy.lua"
      install_integrations
      hook_integrations "$target/lua/config/options.lua"
      echo "LazyVim installed. Keymap help: <leader>sk"
    }

    install_kickstart() {
      clone https://github.com/nvim-lua/kickstart.nvim
      install_integrations
      # kickstart is one readable init.lua; the require goes at the end of it.
      hook_integrations "$target/init.lua"
      echo "kickstart.nvim installed. It is meant to be read and edited: $target/init.lua"
    }

    install_stock() {
      mkdir -p "$target"
      install_integrations
      hook_integrations "$target/init.lua"
      echo "Stock Neovim with launcher integrations only. Try :Tutor if you are new to vim."
    }

    # --- choose -------------------------------------------------------------

    if [ "$integrations_only" -eq 1 ]; then
      if [ ! -d "$target" ]; then
        echo "setup-nvim: $target does not exist; run without --integrations-only first." >&2
        exit 1
      fi
      install_integrations
      if [ -e "$target/lua/chadrc.lua" ]; then
        install_material_theme
        hook_integrations "$target/lua/options.lua"
      elif [ -e "$target/lua/plugins/astrocore.lua" ]; then
        hook_integrations "$target/init.lua"
      elif [ -e "$target/lua/config/options.lua" ]; then
        hook_integrations "$target/lua/config/options.lua"
      else
        hook_integrations "$target/init.lua"
      fi
      echo "Launcher integrations added to $target."
      exit 0
    fi

    if [ -z "$distro" ]; then
      cat <<'MENU'
    Neovim setup

      1) AstroNvim  + wallpaper-matched colourscheme, which-key hints
      2) NvChad     + wallpaper-matched colourscheme, searchable cheatsheet (<leader>ch)
      3) LazyVim    batteries included, many plugins
      4) kickstart  one readable init.lua you own and edit
      5) stock      no distro; just clipboard + line wrap
      6) quit

MENU
      # Enter takes AstroNvim: wallpaper colourscheme plus which-key hints out of
      # the box, which is the friendliest default for someone who has not chosen.
      printf 'Choice [1-6, default 1]: '
      read -r choice
      [ -n "$choice" ] || choice=1
      case "$choice" in
        1) distro=astronvim ;;
        2) distro=nvchad ;;
        3) distro=lazyvim ;;
        4) distro=kickstart ;;
        5) distro=stock ;;
        *) echo "Nothing changed."; exit 0 ;;
      esac
    fi

    # An existing config is never overwritten silently. Side-by-side is the default
    # suggestion: NVIM_APPNAME keeps both configs and both plugin sets apart, so you
    # can try one without losing the other.
    if [ -e "$target" ] && [ "$appname" = "nvim" ]; then
      echo
      echo "$target already exists."
      if [ "$assume_yes" -eq 1 ]; then
        echo "setup-nvim: refusing to replace it non-interactively; pass --appname NAME." >&2
        exit 1
      fi
      cat <<'EXISTS'
      1) install side by side under NVIM_APPNAME (keeps what you have)
      2) replace it
      3) only add launcher integrations to it
      4) quit
EXISTS
      printf 'Choice [1-4]: '
      read -r existing
      case "$existing" in
        1) printf 'Name [%s]: ' "$distro"
           read -r name
           appname="''${name:-$distro}"
           target="$config_home/$appname"
           data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/$appname"
           if [ -e "$target" ]; then
             echo "setup-nvim: $target also exists; pick another name." >&2
             exit 1
           fi ;;
        2) printf 'This deletes %s and its plugins. Type REPLACE to confirm: ' "$target"
           read -r confirm
           [ "$confirm" = "REPLACE" ] || { echo "Nothing changed."; exit 0; }
           rm -rf "$target" "$data_dir" \
                  "''${XDG_STATE_HOME:-$HOME/.local/state}/$appname" \
                  "''${XDG_CACHE_HOME:-$HOME/.cache}/$appname" ;;
        3) exec "$0" --integrations-only --appname "$appname" ;;
        *) echo "Nothing changed."; exit 0 ;;
      esac
    fi

    case "$distro" in
      astronvim) install_astronvim ;;
      nvchad) install_nvchad ;;
      lazyvim) install_lazyvim ;;
      kickstart) install_kickstart ;;
      stock) install_stock ;;
      *) echo "setup-nvim: unknown distro '$distro'" >&2; exit 2 ;;
    esac

    echo
    if [ "$appname" = "nvim" ]; then
      echo "Start it with: nvim"
    else
      echo "Start it with: NVIM_APPNAME=$appname nvim"
    fi
    echo "First launch installs plugins and compiles treesitter parsers — give it a minute."
  '')
]
