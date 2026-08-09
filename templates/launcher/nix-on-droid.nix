{ pkgs, ... }:

{
  # System-level packages: keep this small, the shell lives in home.nix.
  environment.packages = with pkgs; [
    curl
    gnused
    git
    openssh
    which
  ];

  # fish as the login shell for every terminal session.
  user.shell = "${pkgs.fish}/bin/fish";

  # termux-am and friends, wired to the launcher edition's package name.
  android-integration = {
    am.enable = true;
    termux-open.enable = true;
    termux-open-url.enable = true;
    termux-reload-settings.enable = true;
    termux-setup-storage.enable = true;
    termux-wake-lock.enable = true;
    termux-wake-unlock.enable = true;
  };

  # The wiki's everyday commands (nix profile, nix search, nix run) and the
  # flake-based switch all need these; the bare bootstrap leaves them off.
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Read the changelog before changing this value.
  system.stateVersion = "26.05";
}
