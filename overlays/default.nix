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

      # Nix overlay store management scripts
      # These need configuration values, so they're functions that take config
      nix-overlay-scripts = { mountPoint, upperLayer, workDir, buildDir, cacheDir, overlayStoreUrl }:
        let
          substituteVars = script: builtins.replaceStrings
            [ "@mountPoint@" "@upperLayer@" "@workDir@" "@buildDir@" "@cacheDir@" "@overlayStoreUrl@" ]
            [ mountPoint upperLayer workDir buildDir cacheDir overlayStoreUrl ]
            script;

          mkScript = name: scriptFile: runtimeInputs:
            let
              script = prev.writeShellScriptBin name (substituteVars (builtins.readFile scriptFile));
            in prev.symlinkJoin {
              inherit name;
              paths = [ script ] ++ runtimeInputs;
              buildInputs = [ prev.makeWrapper ];
              postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
            };
        in {
          nix-overlay-enable = mkScript "nix-overlay-enable"
            ../nixos-modules/rock5c/nix-overlay-enable
            [ prev.util-linux prev.coreutils prev.systemd ];

          nix-overlay-disable = mkScript "nix-overlay-disable"
            ../nixos-modules/rock5c/nix-overlay-disable
            [ prev.util-linux prev.coreutils prev.systemd ];

          nix-overlay-status = mkScript "nix-overlay-status"
            ../nixos-modules/rock5c/nix-overlay-status
            [ prev.util-linux prev.coreutils prev.systemd ];
        };
    })
  ];
}
