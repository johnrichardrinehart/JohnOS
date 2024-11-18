# Edit this configuration file to define what should be installed on

# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dev.johnrinehart.system;
in
{
  options.dev.johnrinehart.system = {
    enable = lib.mkEnableOption "John's system";
  };

  config = lib.mkIf cfg.enable {
    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    networking.useDHCP = false;

    system.stateVersion = "24.05"; # Did you read the comment?

    programs.zsh.enable = true;
    # Define a user account. Don't forget to set a password with ‘passwd’.
    ## consider using https://stackoverflow.com/a/54505212 for merging extraGroups
    users = {
      groups = {
        john = { };
      };
      users = {
        john = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "vboxsf"
            "audio"
            "docker"
            "adbusers"
            "video"
          ]; # Enable ‘sudo’ for the user. And enable access to VBox shared folders
          shell = pkgs.zsh;
          hashedPassword = "$6$IQcYRQaTKCrDfClQ$k7MAqJDodwnGdtpj7zXEHq9UsPDAeME5XweKRosRjA8QFfMc2k.eZoGTHc4pnHAWAxaNtYylWN85fkroQg7lj.";
          group = "john";
        };
      };
    };

    # https://github.com/VTimofeenko/home-manager/blob/3d9ea6d74ee511cd8664f4a486ce65bd39e03ea8/experiments/homed.nix
    # systemd.package = pkgs.systemd.override (old: { withHomed = true; });

    # cidkid from #nixos
    # systemd.package = (pkgs.systemd.override { withHomed = true; });

    # overlay: NobbZ says don't do this because
    # https://zimbatm.com/notes/1000-instances-of-nixpkgs
    # nixpkgs.overlays = [
    #   (self: super: {
    #     systemd = (super.systemd.override {
    #       withHomed = true;
    #       withCryptsetup = true;
    #       cryptsetup = super.cryptsetup;
    #     });
    #   })
    # ];

    # Enable touchpad support (enabled default in most desktopManager).
    services.libinput.enable = true;
  };
}
