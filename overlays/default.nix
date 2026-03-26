inputs: {
  default = inputs.nixpkgs.lib.composeManyExtensions [
    (final: prev: {
      agent-deck = final.callPackage ../packages/agent-deck.nix { };
      # Backport of NixOS/nix#15572 for the stale-file-handle regression tracked
      # in NixOS/nixpkgs#496466. Drop this once nix 2.33 includes that test fix.
      nix_2_33_skip_stale_file_handle_test = prev.nixVersions.nix_2_33.appendPatches [
        ../patches/nix-2.33-skip-stale-file-handle-test.patch
      ];
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
