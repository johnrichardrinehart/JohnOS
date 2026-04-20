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

    # tmux control-mode NULL control_state crash:
    # https://www.mail-archive.com/tmux-users@googlegroups.com/msg02193.html
    # https://www.mail-archive.com/tmux-users@googlegroups.com/msg02194.html
    (final: prev: {
      tmux = prev.tmux.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (final.fetchpatch2 {
            url = "https://github.com/tmux/tmux/commit/e5a2a25fafb8ee107c230d8acad694f6b635f8bb.patch";
            hash = "sha256-4w+nTSOmzeZPdJRnWuFkB9Z150n3FCC1wQyipUIRlaw=";
          })
          (final.fetchpatch2 {
            url = "https://github.com/tmux/tmux/commit/31c93c483afa4f94ef2091c8d9f25db4731d0e7f.patch";
            hash = "sha256-hJIpveWxh5/eTTKOy5VllugMBhihvafxo+XGFABqicc=";
          })
        ];
      });
    })
  ];
}
