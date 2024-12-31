inputs: {
  default = inputs.nixpkgs.lib.composeManyExtensions [
    # util-linux patch for handling dots in paths properly
		(final: prev: {
		 util-linux = prev.util-linux.overrideAttrs (old: {
				 patches = old.patches ++ [ ../patches/util-linux.patch ];
				 });
		 })
  ];
}
