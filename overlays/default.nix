inputs: {
  default = inputs.nixpkgs.lib.composeManyExtensions [
    (final: prev: {
      agent-deck = final.callPackage ../packages/agent-deck.nix { };
      codex-weekly-pace = final.callPackage ../packages/codex-weekly-pace { };
      codex-cli-nix = final.callPackage ../packages/codex-cli-nix.nix { };
      framework-ec = final.callPackage ../packages/framework-ec { };
      framework-ec-flash = final.callPackage ../packages/framework-ec-flash.nix {
        frameworkTool = final.framework-tool;
      };
      fuzzel_1_14_1 = import ../packages/fuzzel_1_14_1.nix {
        inherit (final) fetchurl;
        inherit (prev) fuzzel;
      };
      fuzzel = final.fuzzel_1_14_1;
      herdr = final.callPackage ../packages/herdr.nix { };
      "niri-26.04" = final.callPackage ../packages/niri.nix { };
      niri-cycle-display-mode = final.callPackage ../packages/niri-cycle-display-mode {
        niri = final."niri-26.04";
      };
      omx-agent-tools = final.callPackage ../packages/omx-agent-tools.nix { };
      oh-my-codex = final.callPackage ../packages/oh-my-codex.nix { };
      repo-manager = final.callPackage ../packages/repo-manager.nix {
        inherit (final.stdenv.hostPlatform) system;
      };
      repod = final.callPackage ../packages/repod.nix {
        inherit (final.stdenv.hostPlatform) system;
      };
    })

    (_final: prev: {
      kdlfmt = prev.callPackage ../packages/kdlfmt.nix {
        inherit (prev) kdlfmt;
      };
    })

    # util-linux patch for handling dots in paths properly
    (_final: prev: {
      util-linux = import ../packages/util-linux-patched.nix {
        inherit (prev) util-linux;
      };
    })

    # tmux control-mode NULL control_state crash:
    # https://www.mail-archive.com/tmux-users@googlegroups.com/msg02193.html
    # https://www.mail-archive.com/tmux-users@googlegroups.com/msg02194.html
    (_final: prev: {
      tmux = import ../packages/tmux-patched.nix {
        inherit (prev) fetchpatch2;
        inherit (prev) tmux;
      };
    })
  ];
}
