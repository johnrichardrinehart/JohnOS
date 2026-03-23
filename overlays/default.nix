inputs: {
  default = inputs.nixpkgs.lib.composeManyExtensions [
    # util-linux patch for handling dots in paths properly
    (final: prev:
      let
        customPackages = import ../packages/default.nix { pkgs = final; };
      in
      {
        util-linux = prev.util-linux.overrideAttrs (old: {
          patches = (old.patches or []) ++ [ ../patches/util-linux.patch ];
        });
      }
      // customPackages)
  ];
}
