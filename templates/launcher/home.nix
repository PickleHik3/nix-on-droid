{ config, lib, pkgs, ... }:

{
  # CLI stack. fish config below expects these; every block in it is guarded
  # with `type -q`, so removing a package here degrades gracefully.
  home.packages = with pkgs; [
    # shell + prompt
    fish
    oh-my-posh
    # files & navigation
    ncurses  # clear/tput for the fish greeting and cursor helpers
    eza
    zoxide
    yazi
    fd
    ripgrep
    # eye candy — fastfetch renders its logo (GIF included) over the kitty
    # graphics protocol, which the launcher terminal advertises natively.
    fastfetch
    timg
    chafa
    # Neovim toolchain, enough for any of the setups `setup-nvim` offers:
    # treesitter compiles grammars with cc, plugin managers clone with git,
    # pickers want rg/fd (above). The rest is what the distro health checks ask
    # for on a fresh install: the tree-sitter CLI (an outright error without it),
    # fzf and lazygit for the pickers and the git keymap, python3 for plugins
    # that build luarocks through hererocks, and imagemagick so image previews
    # render more than plain PNGs over the launcher's kitty graphics support.
    # Drop imagemagick if you want the smaller closure — previews degrade
    # rather than break.
    neovim
    gcc
    gnumake
    unzip
    tree-sitter
    fzf
    lazygit
    python3
    imagemagick
  ]
  # sshd lifecycle commands (sshd-start/stop/status, sshd-autostart on|off):
  # declarative flags and store paths, imperative user-controlled startup.
  ++ (import ./sshd-tools.nix { inherit pkgs; })
  # `setup-nvim`: choose a Neovim setup (NvChad / LazyVim / kickstart / stock) and
  # wire in the launcher integrations. Nothing is installed until you run it.
  ++ (import ./nvim-tools.nix { inherit pkgs; });

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

  # fastfetch with the kitty-protocol animated logo. Drop a GIF at
  # ~/Pictures/gif/skel.gif (or edit logo.source) — fastfetch falls back to
  # text output while the file is missing.
  xdg.configFile."fastfetch/config.jsonc".source = ./config/fastfetch/config.jsonc;

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
  };

  home.sessionPath = [ "$HOME/.local/bin" ];

  # Read the changelog before changing this value.
  home.stateVersion = "26.05";
}
