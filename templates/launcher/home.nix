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
    # LazyVim toolchain: treesitter compiles grammars with cc, lazy.nvim
    # clones plugins with git, telescope wants rg/fd (above).
    # The rest of this block is what `:checkhealth lazyvim` asks for on a
    # fresh install: the tree-sitter CLI (an outright error without it),
    # fzf and lazygit for the pickers and the git keymap, python3 so
    # lazy.nvim's hererocks can build luarocks when a plugin needs it, and
    # imagemagick so snacks.image can render more than plain PNGs over the
    # launcher's kitty graphics support. Drop imagemagick if you want the
    # smaller closure — image previews degrade rather than break.
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
  ++ (import ./sshd-tools.nix { inherit pkgs; });

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

  # LazyVim starter, cloned once on first activation. ~/.config/nvim stays
  # yours afterwards — this never overwrites an existing config.
  home.activation.lazyvim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${config.xdg.configHome}/nvim" ]; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone --depth=1 \
        https://github.com/LazyVim/starter "${config.xdg.configHome}/nvim"
      $DRY_RUN_CMD rm -rf "${config.xdg.configHome}/nvim/.git"
      # Nothing in the starter needs luarocks — lazy.nvim says as much in its
      # own health check — but with rocks left on it still wants to build
      # hererocks on the phone, and reports an error until it does.
      $DRY_RUN_CMD ${pkgs.gnused}/bin/sed -i \
        's|^  install = { colorscheme|  rocks = { enabled = false },\n  install = { colorscheme|' \
        "${config.xdg.configHome}/nvim/lua/config/lazy.lua"
    fi
  '';

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
