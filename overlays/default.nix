inputs: {
  default = inputs.nixpkgs.lib.composeManyExtensions [
    # util-linux patch for handling dots in paths properly (e.g., local-overlay-store)
    (final: prev: {
      util-linux = prev.util-linux.overrideAttrs (old: {
        patches = (old.patches or []) ++ [ ../patches/util-linux.patch ];
      });
    })

    # Custom packages for Rock 5C
    (final: prev: {
      nixos-rebuild-bake = let
        script = prev.writeShellScriptBin "nixos-rebuild-bake"
          (builtins.readFile ../nixos-modules/rock5c/nixos-rebuild-bake);
      in prev.symlinkJoin {
        name = "nixos-rebuild-bake";
        paths = [ script prev.rsync ];
        buildInputs = [ prev.makeWrapper ];
        postBuild = "wrapProgram $out/bin/nixos-rebuild-bake --prefix PATH : $out/bin";
      };
    })
  ];
}
