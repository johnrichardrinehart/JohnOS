inputs:
let
  lib = inputs.nixpkgs.lib;
in
lib.mapAttrs (
  dir: _:
    lib.nixosSystem {
      modules = [
        {
          nixpkgs.overlays = [
            inputs.rock5c-nixos.overlays.default
            inputs.self.overlays.default
          ];
        }
        inputs.rock5c-nixos.nixosModules.default
        ./${dir}
        ../nixos-modules
      ];
      specialArgs = { inherit inputs; };
    }
) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.))
