{ mako }:

mako.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ../nixos-modules/desktop/0001-feat-support-etc-mako-config.patch
  ];
})
