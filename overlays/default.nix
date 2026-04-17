inputs: {
  default = inputs.nixpkgs.lib.composeManyExtensions [
    (final: prev: {
      agent-deck = final.callPackage ../packages/agent-deck.nix { };
      codex-cli-nix = final.callPackage ../packages/codex-cli-nix.nix { };
      omx-agent-tools = final.callPackage ../packages/omx-agent-tools.nix { };
      oh-my-codex = final.callPackage ../packages/oh-my-codex.nix { };
    })

    (final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (pyFinal: pyPrev: {
            # These upstream tests are sensitive to low RLIMIT_NOFILE values in
            # Nix build sandboxes and can fail before reaching the behavior they
            # are actually trying to exercise.
            watchdog = pyPrev.watchdog.overridePythonAttrs (old: {
              disabledTests = (old.disabledTests or [ ]) ++ [ "test_select_fd" ];
            });

            virtualenv = pyPrev.virtualenv.overridePythonAttrs (old: {
              disabledTests = (old.disabledTests or [ ]) ++ [ "test_too_many_open_files" ];
            });
          })
        ];

      watchdog = final.python3Packages.watchdog;
      virtualenv = final.python3Packages.virtualenv;
    })

    (final: prev:
      let
        qt6Overlay = qfinal: qprev: {
          # QtWebEngine generates linker_ulimit.sh with a hardcoded /bin/bash
          # shebang, which fails in Nix build sandboxes where /bin/bash does not
          # exist. Upstream generates the helper from QtConfigureHelpers.cmake
          # when the open-files limit is below 4096, and a downstream FreeBSD
          # bug reports the same linker_ulimit.sh behavior:
          # https://github.com/qt/qtwebengine/blob/dev/cmake/QtConfigureHelpers.cmake
          # https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=270041
          qtwebengine = qprev.qtwebengine.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace cmake/QtConfigureHelpers.cmake \
                --replace-fail '#!/bin/bash' '#!${final.buildPackages.bash}/bin/bash'
            '';
          });
        };
        patchedQt6 = prev.qt6.overrideScope qt6Overlay;
      in
      {
        qt6 = patchedQt6 // {
          override = args: (prev.qt6.override args).overrideScope qt6Overlay;
        };
        qt6Packages = final.qt6;
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
