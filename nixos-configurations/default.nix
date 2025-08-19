inputs:
let
  lib = inputs.nixpkgs.lib;
in
lib.mapAttrs (
  dir: _:
  lib.nixosSystem {
    modules = [
      ./${dir}
      ../nixos-modules
    ];

    specialArgs = { inherit inputs; };
  }
) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.))
