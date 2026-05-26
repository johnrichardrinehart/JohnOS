{ util-linux }:

util-linux.overrideAttrs (old: {
  patches = old.patches ++ [ ../patches/util-linux.patch ];
})
