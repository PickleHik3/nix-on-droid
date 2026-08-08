{
  description = "Termux Launcher nix edition — opinionated shell (fish, oh-my-posh, LazyVim, eza, zoxide, yazi, fastfetch, timg)";

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

  outputs = { nixpkgs, home-manager, nix-on-droid, ... }: {
    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs { system = "aarch64-linux"; };
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
