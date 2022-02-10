{ nixpkgs, pkgs, lib, ... } @ args:
let
  overriddenDbeaver = (pkgs.dbeaver.overrideAttrs (old: rec {
    fetchedMavenDeps = old.fetchedMavenDeps.overrideAttrs (_: rec {
      outputHash = args.sha;
    });
  }));

  overlayedDbeaver = (self: super: { dbeaver = overriddenDbeaver; });

  overlays = if args.flavor == "hmOverlay" then [ overlayedDbeaver ] else [ ];

  dbeaver = if args.flavor == "hmOverride" then overriddenDbeaver else pkgs.dbeaver;

in
{
  nixpkgs.overlays = overlays;

  home.packages = [ dbeaver ];

  home.stateVersion = "21.05";
}
