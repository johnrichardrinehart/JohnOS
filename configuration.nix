{ config, pkgs, ... } @ args:
let
  overriddenDbeaver = orig: (orig.overrideAttrs (old: rec {
    fetchedMavenDeps = old.fetchedMavenDeps.overrideAttrs (_: rec {
      outputHash = args.sha;
    });
  }));

  overlayedDbeaver = (self: super: { dbeaver = overriddenDbeaver super.dbeaver; });

  overlays =
    if args.flavor == "globalOverlay" then [ overlayedDbeaver ] else [ ];

  dbeaver = if args.flavor == "globalOverride" then overriddenDbeaver pkgs.dbeaver else pkgs.dbeaver;
in
{
  boot.loader.grub.devices = [ "/" ];

  fileSystems = {
    "/" = {
      fsType = "tmpfs";
      device = "nothing";
    };
  };

  users.users = {
    john = {
      isNormalUser = true;
    };
  };

  nixpkgs.overlays = overlays;

  environment.systemPackages = [ dbeaver ];

  system.stateVersion = "21.05"; # Did you read the comment?
}
