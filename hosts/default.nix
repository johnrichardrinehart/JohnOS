inputs:
let
  lib = inputs.nixpkgs.lib;
in
lib.mapAttrs (
  dir: _:
  lib.nixosSystem {
    modules = [
      # may need to be `nixosModules.home-manager`
      inputs.home-manager.nixosModules.default
      #inputs.nixos-hardware.nixosModules.default
      ./${dir}
      ({ pkgs, ... }: {
        nix = {
          registry = {
            nixpkgs.flake = inputs.nixpkgs;
            templates.flake = inputs.flake-templates;
          };

          package = pkgs.nix;

          settings = {
            substituters = [
              "https://johnos.cachix.org"
              ];

              trusted-public-keys = [
                "johnos.cachix.org-1:wwbcQLNTaO9dx0CIXN+uC3vFl8fvhtkJbZWzMXWLFu0="
                ];

                trusted-users = [ "john" ];
              };

              extraOptions =
                let
                  empty_registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
                in
                "experimental-features = nix-command flakes\n" + "flake-registry = ${empty_registry}";
                nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
              };

      })
    ];
  }
  ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.))
