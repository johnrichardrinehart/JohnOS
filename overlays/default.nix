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
      # Nix overlay store management scripts
      # These need configuration values, so they're functions that take config
      nix-overlay-scripts = { mountPoint, upperLayer, workDir, buildDir, cacheDir, overlayStoreUrl, lowerStoreDev }:
        let
          substituteVars = script: builtins.replaceStrings
            [ "@mountPoint@" "@upperLayer@" "@workDir@" "@buildDir@" "@cacheDir@" "@overlayStoreUrl@" "@lowerStoreDev@" ]
            [ mountPoint upperLayer workDir buildDir cacheDir overlayStoreUrl lowerStoreDev ]
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
          nix-overlay-setup = mkScript "nix-overlay-setup"
            ../nixos-modules/rock5c/nix-overlay-setup
            [ prev.util-linux prev.coreutils prev.systemd ];

          nixos-rebuild-local = mkScript "nixos-rebuild-local"
            ../nixos-modules/rock5c/nixos-rebuild-local
            [ prev.util-linux prev.coreutils prev.nix ];
        };
    })
  ];
}
