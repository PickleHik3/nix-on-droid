# `setup-launcher` — turn a bare first boot into the launcher's shell environment.
#
# The first boot leaves a minimal flake and a bash prompt. Getting the real
# environment is four commands, one of which deletes two files, and every one of
# them has to be typed correctly at a phone keyboard before anything works. That
# is a poor first hour, and it is the same four commands every time, so it is a
# script.
#
# It lives in the base environment (see path.nix) rather than in the template,
# because it is what installs the template.
#
#   setup-launcher                 back up the minimal files, init the template, switch
#   setup-launcher --no-switch     leave the switch to you
#   setup-launcher --template REF  a different flake template reference
#
# Existing files are moved aside with a timestamp, never deleted: `nix flake
# init` refuses to overwrite, and a user who has already edited the minimal
# config should get it back if this goes wrong.
{ pkgs }:

pkgs.writeShellScriptBin "setup-launcher" ''
  set -eu
  # The base environment ships no coreutils, so `date` and `mv` are not on PATH by
  # themselves. Keep the inherited PATH behind ours: `nix` and `nix-on-droid` are
  # the whole point of this script and have to come from the user's environment.
  export PATH="${pkgs.lib.makeBinPath [ pkgs.coreutils ]}:$PATH"

  template="github:PickleHik3/nix-on-droid/launcher-nix#launcher"
  config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
  flake_dir="''${NIX_ON_DROID_FLAKE_DIR:-$config_home/nix-on-droid}"
  do_switch=1

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-switch) do_switch=0; shift ;;
      --template) template="''${2:-}"; shift 2 ;;
      --flake-dir) flake_dir="''${2:-}"; shift 2 ;;
      -h|--help)
        echo "usage: setup-launcher [--no-switch] [--template REF] [--flake-dir DIR]"
        exit 0 ;;
      *) echo "setup-launcher: unknown option '$1'" >&2; exit 1 ;;
    esac
  done

  [ -d "$flake_dir" ] || { echo "setup-launcher: no config directory at $flake_dir" >&2; exit 1; }

  # home.nix only exists once the template is in place, so it is the marker for
  # "already done". Re-initialising would overwrite an edited config.
  if [ -e "$flake_dir/home.nix" ]; then
    echo "The launcher template is already installed in $flake_dir."
    echo "Change what is installed with 'setup-toolkits', or add packages to home.nix and run:"
    echo "  nix-on-droid switch --flake $flake_dir"
    exit 0
  fi

  stamp="$(date +%Y%m%d-%H%M%S)"
  moved=""
  for f in flake.nix nix-on-droid.nix flake.lock; do
    if [ -e "$flake_dir/$f" ]; then
      mv "$flake_dir/$f" "$flake_dir/$f.bak-$stamp"
      moved="$moved $f"
      echo "  kept your $f as $f.bak-$stamp"
    fi
  done

  restore() {
    for f in $moved; do
      if [ -e "$flake_dir/$f.bak-$stamp" ]; then
        mv -f "$flake_dir/$f.bak-$stamp" "$flake_dir/$f"
      fi
    done
    return 0
  }

  echo "Fetching the launcher template..."
  if ! (cd "$flake_dir" && nix flake init -t "$template"); then
    echo "setup-launcher: could not initialise the template — restoring your files." >&2
    restore
    exit 1
  fi

  if [ "$do_switch" = 0 ]; then
    echo "Template installed. Apply it when you are ready:"
    echo "  nix-on-droid switch --flake $flake_dir"
    exit 0
  fi

  echo ""
  echo "Building the environment. This takes a few minutes, and longer on an older"
  echo "phone. Keep the app in the foreground — Android cuts network to background"
  echo "apps, which stalls the download."
  echo ""
  if ! nix-on-droid switch --flake "$flake_dir"; then
    echo "" >&2
    echo "setup-launcher: the switch failed, so nothing changed — the environment you" >&2
    echo "are in is still the one you had. The error above names the file it tripped" >&2
    echo "on. The template is in $flake_dir; fix it and run:" >&2
    echo "  nix-on-droid switch --flake $flake_dir" >&2
    exit 1
  fi

  echo ""
  echo "Done. Open a new session to get fish, the prompt and the rest —"
  echo "the login shell only changes for sessions started after a switch."
  echo ""
  echo "Then: 'setup-toolkits' picks what is installed (node, go, python are off"
  echo "by default), and 'setup-nvim' sets up Neovim."
''
