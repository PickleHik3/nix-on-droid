{ config, lib, pkgs, ... }:

let
  # Which groups to install. `setup-toolkits` writes this file; see the comments
  # in it for what each group costs.
  toolkits = import ./toolkits.nix;

  # A Neovim distro compiles treesitter grammars on first launch, so the editor
  # group cannot stand without a compiler.
  wantBuild = toolkits.build || toolkits.editor;

  # Installed whatever the toolkits say: fish is the login shell either way (see
  # nix-on-droid.nix), and its shipped config reaches for clear/tput on every
  # greeting. Gating these behind the shell toolkit left a bare `shell = false`
  # environment erroring on each new prompt.
  basePackages = with pkgs; [
    ncurses # clear/tput for the fish greeting and cursor helpers
  ];

  # Shell, prompt, navigation. The shipped fish config guards every block with
  # `type -q`, so removing a package here degrades gracefully.
  shellPackages = with pkgs; [
    fish
    oh-my-posh
    eza
    zoxide
    yazi
    fd
    ripgrep
    fzf
  ];

  # fastfetch renders its logo (an animated GIF, shipped below) over the kitty
  # graphics protocol, which the launcher terminal advertises natively.
  eyeCandyPackages = with pkgs; [
    fastfetch
    timg
    chafa
  ];

  # Enough for any of the setups `setup-nvim` offers: plugin managers clone with
  # git, pickers want rg/fd (above), and the rest is what the distro health
  # checks ask for on a fresh install — the tree-sitter CLI (an outright error
  # without it), lazygit for the git keymap, python3 for plugins that build
  # luarocks through hererocks, and imagemagick so image previews render more
  # than plain PNGs. Drop imagemagick for a smaller closure; previews degrade
  # rather than break.
  editorPackages = with pkgs; [
    neovim
    tree-sitter
    lazygit
    python3
    imagemagick
  ];

  # Base development toolchain — the rough equivalent of a `base-devel` group.
  # Libraries to build *against* stay out on purpose: they are per-project, and
  # `nix shell nixpkgs#zlib.dev nixpkgs#openssl.dev` is the tool for that.
  buildPackages = with pkgs; [
    gcc
    gnumake
    cmake
    pkg-config
    binutils
    autoconf
    automake
    libtool
    patch
    gettext
    file
    unzip
    gnutar
    gzip
    xz
  ];

  # Language toolchains. Their *global* installs are redirected into $HOME by the
  # session variables further down, so `npm install -g`, `go install` and
  # `uv tool install` keep working across switches, rollbacks and
  # `nix-collect-garbage` — none of them can write into the read-only nix store
  # profile that home-manager owns.
  nodePackages = with pkgs; [ nodejs ];
  goPackages = with pkgs; [ go ];
  pythonPackages = with pkgs; [ python3 uv ];

  # Anything that does not belong to a toolkit. This is the list to edit for a
  # one-off: uncomment a line, or add your own, then
  #
  #   nix-on-droid switch --flake ~/.config/nix-on-droid
  #
  # Names are nixpkgs attribute names — search them with `nix search nixpkgs
  # <term>`, or on https://search.nixos.org/packages. A name that does not
  # exist fails the switch by name, and the old environment stays active until
  # you fix it, so a typo here costs nothing but the error message.
  extraPackages = with pkgs; [
    # htop          # process viewer
    # tmux          # the launcher has its own panes and windows, but tmux still works
    # jq            # JSON on the command line
    # wget          # curl is already here
    # rsync
    # sqlite
    # ffmpeg        # large closure
  ];
in

{
  home.packages =
    basePackages
    ++ lib.optionals toolkits.shell shellPackages
    ++ lib.optionals toolkits.eyeCandy eyeCandyPackages
    ++ lib.optionals toolkits.editor editorPackages
    ++ lib.optionals wantBuild buildPackages
    ++ lib.optionals toolkits.node nodePackages
    ++ lib.optionals toolkits.go goPackages
    ++ lib.optionals toolkits.python pythonPackages
    # Your own additions, from the list above. Empty by default.
    ++ extraPackages
    # sshd lifecycle commands (sshd-start/stop/status, sshd-autostart on|off):
    # declarative flags and store paths, imperative user-controlled startup.
    ++ (import ./sshd-tools.nix { inherit pkgs; })
    # `setup-toolkits`: the checklist that edits toolkits.nix and switches.
    ++ (import ./toolkit-tools.nix { inherit pkgs; })
    # `setup-nvim`: choose a Neovim setup (AstroNvim / NvChad / LazyVim /
    # kickstart / stock) and wire in the launcher integrations. Nothing is
    # installed until you run it.
    ++ lib.optionals toolkits.editor (import ./nvim-tools.nix { inherit pkgs; });

  # The launcher's own fish config: Material You palette exports, PATH to
  # launcherctl/tai, oh-my-posh init. Read-only (a store symlink) by design —
  # user settings belong in conf.d/personal.fish below.
  xdg.configFile."fish/config.fish".source = ./config/config.fish;

  # Editor, aliases, sshd autostart, ls/cd helpers: copied once into a plain
  # writable file so it can be edited without a switch, and never overwritten
  # afterwards. Delete it and switch again for a fresh copy.
  home.activation.personalFishConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${config.xdg.configHome}/fish/conf.d/personal.fish" ]; then
      $DRY_RUN_CMD mkdir -p "${config.xdg.configHome}/fish/conf.d"
      $DRY_RUN_CMD cp ${./config/personal.fish} \
        "${config.xdg.configHome}/fish/conf.d/personal.fish"
      $DRY_RUN_CMD chmod u+w "${config.xdg.configHome}/fish/conf.d/personal.fish"
    fi
  '';

  # oh-my-posh themes the fish config probes for, in preference order.
  xdg.configFile."ohmyposh/aliens-material.omp.json".source =
    ./config/ohmyposh/aliens-material.omp.json;
  xdg.configFile."ohmyposh/termux-launcher.omp.json".source =
    ./config/ohmyposh/termux-launcher.omp.json;

  # fastfetch with the kitty-protocol GIF logo.
  xdg.configFile."fastfetch/config.jsonc" = lib.mkIf toolkits.eyeCandy {
    source = ./config/fastfetch/config.jsonc;
  };

  # The GIF the config points at: copied once to a writable path, so replacing
  # it with your own is `cp yours.gif ~/Pictures/gif/skel.gif` and no switch.
  # An existing file is never overwritten. Without the animation patch (see
  # `animatedFastfetchLogo` in toolkits.nix) fastfetch draws the first frame.
  home.activation.fastfetchLogo = lib.mkIf toolkits.eyeCandy
    (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "$HOME/Pictures/gif/skel.gif" ]; then
        $DRY_RUN_CMD mkdir -p "$HOME/Pictures/gif"
        $DRY_RUN_CMD cp ${./config/fastfetch/logo.gif} "$HOME/Pictures/gif/skel.gif"
        $DRY_RUN_CMD chmod u+w "$HOME/Pictures/gif/skel.gif"
      fi
    '');

  # No Neovim config is installed automatically. Earlier revisions cloned the
  # LazyVim starter here, which picked a fairly opinionated distro on the user's
  # behalf; `setup-nvim` asks instead, and can install alongside an existing
  # config under NVIM_APPNAME. Anyone who already has ~/.config/nvim keeps it
  # untouched — the old hook skipped existing configs too, so switching to the
  # chooser changes nothing for them.

  # `gx` in neovim, and anything else that shells out to xdg-open, has no
  # handler inside the proot. Android already has one — hand the URL to
  # termux-open, which android-integration wires to the launcher edition.
  home.file.".local/bin/xdg-open" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec termux-open "$@"
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less";
    # Nothing in the bootstrap sets a locale, so glibc falls back to "C" and
    # every UTF-8 box-drawing character, prompt glyph and neovim health check
    # misbehaves. C.UTF-8 is built into glibc — no locale archive needed.
    LANG = "C.UTF-8";
  } // lib.optionalAttrs toolkits.node {
    # npm's default prefix is the nix profile, which is a read-only store path:
    # `npm install -g` fails there, and would be discarded by the next switch
    # even if it did not. A directory in $HOME is outside nix's bookkeeping, so
    # globally installed CLIs persist and stay on PATH (see sessionPath).
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  } // lib.optionalAttrs toolkits.go {
    # Same reasoning: `go install` needs a writable GOBIN, and the module cache
    # is worth keeping between builds.
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
  } // lib.optionalAttrs toolkits.python {
    # uv's own Python downloads are python-build-standalone binaries that expect
    # a distro loader (/lib/ld-linux-aarch64.so.1), which does not exist inside
    # the proot — they fail with "no such file or directory" on a path that is
    # plainly there. Point uv at the nix python3 instead; `uv venv`, `uv pip`,
    # `uv tool install` and `uvx` all work against it.
    UV_PYTHON_DOWNLOADS = "never";
    UV_PYTHON_PREFERENCE = "only-system";
  };

  # Where the globally installed binaries of each package manager land. Listed
  # unconditionally: a missing directory costs nothing on PATH, and enabling a
  # toolkit later then needs no new session.
  home.sessionPath = [
    "$HOME/.local/bin" # uv tool install, pipx, and anything you drop yourself
    "$HOME/.npm-global/bin" # npm install -g
    "$HOME/go/bin" # go install
  ];

  # Read the changelog before changing this value.
  home.stateVersion = "26.05";
}
