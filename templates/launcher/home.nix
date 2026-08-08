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
    neovim
    gcc
    gnumake
    unzip
  ];

  # The launcher's stock fish config: Material You palette exports, eza/zoxide
  # wrappers, yazi `y` helper, oh-my-posh init. Identical file to the apt
  # editions' example, so the shell feels the same across editions.
  xdg.configFile."fish/config.fish".source = ./config/config.fish;

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
    fi
  '';

  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less";
  };

  # Read the changelog before changing this value.
  home.stateVersion = "26.05";
}
