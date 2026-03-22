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
) (
  lib.filterAttrs (
    dir: type: type == "directory" && builtins.pathExists (./. + "/${dir}/default.nix")
  ) (builtins.readDir ./.)
)
