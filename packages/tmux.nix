{ fetchpatch2, tmux }:

tmux.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    (fetchpatch2 {
      url = "https://github.com/tmux/tmux/commit/31c93c483afa4f94ef2091c8d9f25db4731d0e7f.patch";
      hash = "sha256-JvftZZhQTntAfm9LXTKWCkDmA4gx0SgG7Okv12nNdyY=";
    })
  ];
})
