inputs: {
  default = inputs.nixpkgs.lib.composeManyExtensions [
    (final: prev: {
      agent-deck = final.callPackage ../packages/agent-deck.nix { };
      codex-weekly-pace = final.callPackage ../packages/codex-weekly-pace.nix { };
      codex-cli-nix = final.callPackage ../packages/codex-cli-nix.nix { };
      framework-ec = final.callPackage ../packages/framework-ec.nix { };
      framework-ec-flash = final.callPackage ../packages/framework-ec-flash.nix {
        frameworkTool = final.framework-tool;
      };
      fuzzel_1_14_1 = prev.fuzzel.overrideAttrs (_old: rec {
        version = "1.14.1";
        src = final.fetchurl {
          url = "https://codeberg.org/dnkl/fuzzel/archive/${version}.tar.gz";
          hash = "sha256-xkFnhsOgYAuK2R7ZUcQ8ACpjmHDDgjtKYMkQRC9K4Jc=";
        };
      });
      fuzzel = final.fuzzel_1_14_1;
      herdr = final.callPackage ../packages/herdr.nix { };
      "niri-26.04" = final.callPackage ../packages/niri.nix { };
      niri-cycle-display-mode = final.callPackage ../packages/niri-cycle-display-mode.nix {
        niri = final."niri-26.04";
      };
      omx-agent-tools = final.callPackage ../packages/omx-agent-tools.nix { };
      oh-my-codex = final.callPackage ../packages/oh-my-codex.nix { };
    })

    (final: prev: {
      kdlfmt =
        let
          kdl-rs = final.fetchFromGitHub {
            owner = "johnrichardrinehart";
            repo = "kdl-rs";
            rev = "15722b3284e391ea340e66ccc7577a0f59d49717";
            hash = "sha256-te59tvkYiJXtZg6aBCpjM9cM9eWZJ1clRJUJR9OzfgU=";
          };
          kdl-rs-cargo-patch = final.writeText "kdlfmt-kdl-rs.patch" ''
            diff --git a/Cargo.lock b/Cargo.lock
            index 59fdedb..5a094ea 100644
            --- a/Cargo.lock
            +++ b/Cargo.lock
            @@ -416,8 +416,6 @@ dependencies = [
             [[package]]
             name = "kdl"
             version = "6.5.0"
            -source = "registry+https://github.com/rust-lang/crates.io-index"
            -checksum = "81a29e7b50079ff44549f68c0becb1c73d7f6de2a4ea952da77966daf3d4761e"
             dependencies = [
              "kdl 4.7.1",
              "miette 7.6.0",
            @@ -1046,9 +1044,9 @@ checksum = "45e46c0661abb7180e7b9c281db115305d49ca1709ab8242adf09666d2173c65"
             
             [[package]]
             name = "winnow"
            -version = "0.6.24"
            +version = "0.7.15"
             source = "registry+https://github.com/rust-lang/crates.io-index"
            -checksum = "c8d71a593cc5c42ad7876e2c1fda56f314f3754c084128833e64f1345ff8a03a"
            +checksum = "df79d97927682d2fd8adb29682d1140b343be4ac0f08fd68b7765d9c059d3945"
             dependencies = [
              "memchr",
             ]
            diff --git a/Cargo.toml b/Cargo.toml
            index 9b3b2df..516e7e5 100644
            --- a/Cargo.toml
            +++ b/Cargo.toml
            @@ -31,6 +31,9 @@ miette = { version = "7.6.0", features = ["fancy"] }
             predicates = "3.1.4"
             tempfile = "3.26.0"
             
            +[patch.crates-io]
            +kdl = { path = "${kdl-rs}" }
            +
             # The profile that 'dist' will build with
             [profile.dist]
             inherits = "release"
          '';
        in
        final.rustPlatform.buildRustPackage {
          pname = "kdlfmt";
          inherit (prev.kdlfmt) version src;

          cargoPatches = [ kdl-rs-cargo-patch ];
          cargoHash = "sha256-z7roirQoFhjBiCHJMCND0bh+3MR+pZMu1rjjAfmGVC4=";

          nativeBuildInputs = [ final.installShellFiles ];

          postInstall = inputs.nixpkgs.lib.optionalString (final.stdenv.buildPlatform.canExecute final.stdenv.hostPlatform) ''
            installShellCompletion --cmd kdlfmt \
              --bash <($out/bin/kdlfmt completions bash) \
              --fish <($out/bin/kdlfmt completions fish) \
              --zsh <($out/bin/kdlfmt completions zsh)
          '';

          nativeInstallCheckInputs = [ final.versionCheckHook ];
          versionCheckProgramArg = "--version";
          doInstallCheck = true;

          passthru = (prev.kdlfmt.passthru or { }) // {
            inherit kdl-rs;
          };

          meta = prev.kdlfmt.meta // {
            description = "${prev.kdlfmt.meta.description} (patched with John Rinehart's kdl-rs branch)";
          };
        };
    })

    # util-linux patch for handling dots in paths properly
    (_final: prev: {
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
