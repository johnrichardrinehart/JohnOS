inputs:
let
  lib = inputs.nixpkgs.lib;
in
lib.mapAttrs
  (
    dir: _:
    lib.nixosSystem {
      modules = [
        ./${dir}
        ../modules
        inputs.home-manager.nixosModules.default
        ({ ... }: {
          dev.johnrinehart = {
            kernel.latest.enable = true;
            xorg.enable = true;
            systemPackages.enable = true;
          };
        })
        ({ pkgs, ... }: {
          nix = {
            registry = {
              nixpkgs.flake = inputs.nixpkgs;
              templates.flake = inputs.flake-templates;
            };

            package = pkgs.nix;

            settings.trusted-users = [ "john" ];

            extraOptions =
              let
                empty_registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
              in
              ''
                experimental-features = nix-command flakes
                flake-registry = ${empty_registry}
              '';
            nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
          };
        })
      ];
    }
  )
  (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.))
