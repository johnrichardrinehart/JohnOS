# Edit this configuration file to define what should be installed on

# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

args @ { config, pkgs, lib, ... }:
{
  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;

  system.stateVersion = "23.05"; # Did you read the comment?


  programs.zsh.enable = true;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  ## consider using https://stackoverflow.com/a/54505212 for merging extraGroups
  users.users =
    let
      defaultUserAttrs = {
        isNormalUser = true;
        extraGroups = [ "wheel" "vboxsf" "audio" "docker" "adbusers" ]; # Enable ‘sudo’ for the user. And enable access to VBox shared folders
        shell = pkgs.zsh;
      };
    in
    {
      john = defaultUserAttrs // {
        hashedPassword = "$6$IQcYRQaTKCrDfClQ$k7MAqJDodwnGdtpj7zXEHq9UsPDAeME5XweKRosRjA8QFfMc2k.eZoGTHc4pnHAWAxaNtYylWN85fkroQg7lj.";
      };
      ardan = defaultUserAttrs // {
        hashedPassword = "$6$GjNHUPIRR981Cov$TNQYuTmnGSvUMotD.dUqJ7c9dLCJi0hWL7ztsw1icJovNNjO1eA9vNH9ZXmQR0eaBVPgGrsaXAr/c8YouFhtY.";
      };
    };

  # https://github.com/VTimofeenko/home-manager/blob/3d9ea6d74ee511cd8664f4a486ce65bd39e03ea8/experiments/homed.nix
  # systemd.package = pkgs.systemd.override (old: { withHomed = true; });

  # cidkid from #nixos
  # systemd.package = (pkgs.systemd.override { withHomed = true; });

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

  nix = {
    package = pkgs.nix;

    settings = {
      substituters = [
        "https://johnos.cachix.org"
      ];

      trusted-public-keys = [
        "johnos.cachix.org-1:wwbcQLNTaO9dx0CIXN+uC3vFl8fvhtkJbZWzMXWLFu0="
      ];

      trusted-users = [ "john" ];
    };

    extraOptions =
      let
        empty_registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
      in
      "experimental-features = nix-command flakes\n" + "flake-registry = ${empty_registry}";
    registry.nixpkgs.flake = args.nixpkgs;
    registry.templates.flake = args.flake-templates;
    nixPath = [ "nixpkgs=${args.nixpkgs}" ];
  };

  # Use the systemd-boot EFI boot loader.

  nixpkgs.config.allowUnfree = true;

  # networking.hostName = "JohnOS-framework"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.wireless.userControlled.enable = true;
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
}

