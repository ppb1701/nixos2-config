{
  description = "nixos2 NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    public-config = {
      url = "github:ppb1701/nixos-config";  # Main branch, not vm!
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, public-config, home-manager, ... }: {
    nixosConfigurations.nixos2 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      modules = [
        ./hardware-configuration.nix
      
        # Import modules from main server
        "${public-config}/modules/services.nix"
        "${public-config}/modules/monitoring.nix"
        "${public-config}/modules/networking.nix"
        "${public-config}/modules/system.nix"
      
        # Local config
        ./configuration.nix
      
        # Home manager
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.ppb1701 = { ... }: {
            imports = [
              "${public-config}/home/ppb1701.nix"  # CORRECT PATH!
              ./home/local-aliases.nix
            ];
          };
        }
      ];
    };
  };
}
