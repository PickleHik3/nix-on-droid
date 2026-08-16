# `setup-toolkits` — the checklist for what this config installs.
#
# Nix has no install command: the package list is a file, and a switch makes the
# environment match it. That is the good part of the edition and also the part
# that is unfamiliar, so this script does the file edit for people who would
# rather answer a menu than learn the syntax on day one. It only ever flips the
# booleans in ~/.config/nix-on-droid/toolkits.nix and runs the switch — the same
# two steps anyone would do by hand, and `nix-on-droid rollback` undoes the
# result either way.
#
#   setup-toolkits                       menu
#   setup-toolkits --list                current selection
#   setup-toolkits --all                 every toolkit
#   setup-toolkits --essentials          shell + eye candy only
#   setup-toolkits --enable node,go      non-interactive, leaves the rest alone
#   setup-toolkits --disable eyeCandy
#   setup-toolkits --animated-logo       opt into the ~20 min fastfetch rebuild
#   setup-toolkits --no-switch           edit the file, switch yourself later
{ pkgs }:

let
  sed = "${pkgs.gnused}/bin/sed";
in
[
  (pkgs.writeShellScriptBin "setup-toolkits" ''
    set -eu

    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
    flake_dir="''${NIX_ON_DROID_FLAKE_DIR:-$config_home/nix-on-droid}"
    file="$flake_dir/toolkits.nix"

    # Keys, in display order, with the labels the menu prints.
    keys="shell eyeCandy editor build node go python animatedFastfetchLogo"

    label() {
      case "$1" in
        shell)                 echo "shell         fish, oh-my-posh, eza, zoxide, yazi, fd, ripgrep, fzf" ;;
        eyeCandy)              echo "eye-candy     fastfetch with the animated GIF logo, timg, chafa" ;;
        editor)                echo "editor        neovim + setup-nvim (implies build tools)" ;;
        build)                 echo "build         cc, make, cmake, autotools, pkg-config, binutils — build from source" ;;
        node)                  echo "node          nodejs, npm, npx (npm -g installs into ~/.npm-global)" ;;
        go)                    echo "go            go (go install writes ~/go/bin)" ;;
        python)                echo "python        python3, uv, uvx (uv tool install writes ~/.local/bin)" ;;
        animatedFastfetchLogo) echo "animated-logo patched fastfetch so the GIF animates — compiles ~20 min on device" ;;
      esac
    }

    # Accept the nix attribute names and the friendlier hyphenated spellings.
    canon() {
      case "$(echo "$1" | tr 'A-Z' 'a-z')" in
        shell) echo shell ;;
        eyecandy|eye-candy|eye_candy) echo eyeCandy ;;
        editor|nvim|neovim) echo editor ;;
        build|build-tools|basedevel|base-devel) echo build ;;
        node|nodejs|npm) echo node ;;
        go|golang) echo go ;;
        python|python3|uv) echo python ;;
        animatedfastfetchlogo|animated-logo|animated-fastfetch|fastfetch-animation) echo animatedFastfetchLogo ;;
        *) return 1 ;;
      esac
    }

    if [ ! -e "$file" ]; then
      echo "setup-toolkits: $file does not exist." >&2
      echo "This config predates the toolkits split, or lives somewhere else — set" >&2
      echo "NIX_ON_DROID_FLAKE_DIR, or copy toolkits.nix from the launcher template:" >&2
      echo "  nix flake init -t github:PickleHik3/nix-on-droid/launcher-nix#launcher" >&2
      exit 1
    fi
    if [ ! -w "$file" ]; then
      echo "setup-toolkits: $file is not writable." >&2
      exit 1
    fi

    missing=""
    for k in $keys; do
      grep -Eq "^[[:space:]]*$k[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*;" "$file" || missing="$missing $k"
    done
    if [ -n "$missing" ]; then
      echo "setup-toolkits: $file has no line for:$missing" >&2
      echo "Add each as \`  name = false;\` (one per line) and run this again." >&2
      exit 1
    fi

    get() {
      if grep -Eq "^[[:space:]]*$1[[:space:]]*=[[:space:]]*true[[:space:]]*;" "$file"; then
        echo 1
      else
        echo 0
      fi
    }

    put() {
      # Plain if, not `[ ] && x=y`: under `set -e` a false test as a statement
      # of its own ends the script.
      if [ "$2" = "1" ]; then value=true; else value=false; fi
      ${sed} -E -i "s/^([[:space:]]*$1[[:space:]]*=[[:space:]]*)(true|false)([[:space:]]*;)/\1$value\3/" "$file"
    }

    mark() {
      if [ "$(get "$1")" = "1" ]; then printf '✓'; else printf '✗'; fi
    }

    show() {
      echo
      echo "  Toolkits — $file"
      echo
      for k in $keys; do
        printf '    %s  %s\n' "$(mark "$k")" "$(label "$k")"
      done
      echo
    }

    # --- arguments ----------------------------------------------------------

    mode=""
    enable_list=""
    disable_list=""
    do_switch=ask
    animated=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --list|-l) show; exit 0 ;;
        --all) mode=all; shift ;;
        --essentials|--shell) mode=essentials; shift ;;
        --enable) enable_list="''${2:-}"; shift 2 ;;
        --disable) disable_list="''${2:-}"; shift 2 ;;
        --animated-logo) animated=1; shift ;;
        --no-animated-logo) animated=0; shift ;;
        --no-switch) do_switch=no; shift ;;
        --switch|--yes|-y) do_switch=yes; shift ;;
        -h|--help)
          echo "usage: setup-toolkits [--list] [--all | --essentials]"
          echo "                      [--enable a,b] [--disable a,b]"
          echo "                      [--animated-logo] [--no-switch | --yes]"
          echo
          echo "Toolkits:"
          for k in $keys; do printf '  %s\n' "$(label "$k")"; done
          exit 0 ;;
        *) echo "setup-toolkits: unknown option '$1'" >&2; exit 2 ;;
      esac
    done

    apply_list() {
      value="$2"
      # Commas or spaces, either way.
      for raw in $(echo "$1" | tr ',' ' '); do
        if key="$(canon "$raw")"; then
          put "$key" "$value"
        else
          echo "setup-toolkits: unknown toolkit '$raw'" >&2
          exit 2
        fi
      done
    }

    changed=0

    if [ "$mode" = all ]; then
      # Everything that comes prebuilt. The animation patch is a 20-minute
      # on-device compile, so --all does not quietly opt you into it.
      for k in shell eyeCandy editor build node go python; do put "$k" 1; done
      changed=1
    elif [ "$mode" = essentials ]; then
      for k in shell eyeCandy; do put "$k" 1; done
      for k in editor build node go python; do put "$k" 0; done
      changed=1
    fi

    if [ -n "$enable_list" ]; then apply_list "$enable_list" 1; changed=1; fi
    if [ -n "$disable_list" ]; then apply_list "$disable_list" 0; changed=1; fi
    if [ -n "$animated" ]; then put animatedFastfetchLogo "$animated"; changed=1; fi

    # --- menu ---------------------------------------------------------------

    if [ "$changed" -eq 0 ]; then
      show
      cat <<'MENU'
      1) everything            every toolkit above except the animated logo
      2) shell essentials      shell + eye candy, nothing else
      3) pick one by one
      4) quit, change nothing

MENU
      printf 'Choice [1-4, default 3]: '
      read -r choice || choice=""
      [ -n "$choice" ] || choice=3

      case "$choice" in
        1) for k in shell eyeCandy editor build node go python; do put "$k" 1; done ;;
        2) for k in shell eyeCandy; do put "$k" 1; done
           for k in editor build node go python; do put "$k" 0; done ;;
        3) echo
           echo "Enter = keep the current setting."
           for k in $keys; do
             current="$(get "$k")"
             default=n
             [ "$current" = "1" ] && default=y
             printf '  %s\n' "$(label "$k")"
             printf '    install? [y/n, now %s]: ' "$default"
             read -r answer || answer=""
             case "$(echo "''${answer:-}" | tr 'A-Z' 'a-z')" in
               y|yes) put "$k" 1 ;;
               n|no) put "$k" 0 ;;
               *) : ;;  # anything else, including Enter, keeps it
             esac
           done ;;
        *) echo "Nothing changed."; exit 0 ;;
      esac
    fi

    show

    # --- switch -------------------------------------------------------------

    if [ "$(get animatedFastfetchLogo)" = "1" ]; then
      echo "  Note: the animated fastfetch logo has no prebuilt cache entry. The next"
      echo "  switch compiles fastfetch on the phone (~20 min); keep the app in the"
      echo "  foreground, or Android cuts its network."
      echo
    fi

    if [ "$do_switch" = ask ]; then
      printf 'Switch now? [Y/n]: '
      read -r answer || answer=""
      case "$(echo "''${answer:-y}" | tr 'A-Z' 'a-z')" in
        n|no) do_switch=no ;;
        *) do_switch=yes ;;
      esac
    fi

    if [ "$do_switch" = no ]; then
      echo "Saved. Apply it with:"
      echo "  nix-on-droid switch --flake $flake_dir"
      exit 0
    fi

    echo
    nix-on-droid switch --flake "$flake_dir"

    echo
    echo "Done. New binaries appear in a new session — 'exec fish'."
  '')
]
