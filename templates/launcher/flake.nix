{
  description = "Termux Launcher nix edition — opinionated shell (fish, oh-my-posh, eza, zoxide, yazi, fastfetch, neovim, and optional node/go/python toolchains)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-on-droid = {
      url = "github:PickleHik3/nix-on-droid/launcher-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { nixpkgs, home-manager, nix-on-droid, ... }:
    let
      # Same file home.nix reads; see the comments in it. The overlay is gated
      # here because an overlay changes the package set, which is a flake-level
      # decision, and because building a patched fastfetch on the phone is a
      # 20-minute affair nobody should get by accident.
      toolkits = import ./toolkits.nix;
    in
    {
      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          overlays = nixpkgs.lib.optional toolkits.animatedFastfetchLogo (import ./overlays.nix);
        };
        modules = [
          ./nix-on-droid.nix
          {
            home-manager = {
              useGlobalPkgs = true;
              backupFileExtension = "hm-bak";
              config = ./home.nix;
            };
          }
        ];
        home-manager-path = home-manager.outPath;
      };
    };
}
