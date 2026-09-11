{
  description = "NixOS config for Dell Latitude 5490 - niri + noctalia shell";

  inputs = {
    # noctalia tracks recent Quickshell/niri releases, so stay on unstable.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, noctalia, ... }@inputs:
    {
      nixosConfigurations.renegade = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/renegade/configuration.nix
          ./hosts/renegade/hardware-configuration.nix

          disko.nixosModules.disko
          ./hosts/renegade/disko.nix

          noctalia.nixosModules.default

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.nonezerone = import ./home/nonezerone/home.nix;
          }
        ];
      };
    };
}
