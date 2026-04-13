inputs: {
  default = inputs.nixpkgs.lib.composeManyExtensions [
    (final: prev: {
      agent-deck = final.callPackage ../packages/agent-deck.nix { };
      codex-cli-nix = final.callPackage ../packages/codex-cli-nix.nix { };
      omx-agent-tools = final.callPackage ../packages/omx-agent-tools.nix { };
      oh-my-codex = final.callPackage ../packages/oh-my-codex.nix { };
    })

    # util-linux patch for handling dots in paths properly
    (final: prev: {
      util-linux = prev.util-linux.overrideAttrs (old: {
        patches = old.patches ++ [ ../patches/util-linux.patch ];
      });
    })
  ];
}
