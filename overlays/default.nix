inputs: {
  default = inputs.nixpkgs.lib.composeManyExtensions [
    (final: prev: {
      agent-deck = final.callPackage ../packages/agent-deck.nix { };
    })

    # util-linux patch for handling dots in paths properly
    (final: prev:
      let
        customPackages = import ../packages/default.nix { pkgs = final; };
      in
      {
        util-linux = prev.util-linux.overrideAttrs (old: {
          patches = old.patches ++ [ ../patches/util-linux.patch ];
        });
      }
      // customPackages)
  ];
}
