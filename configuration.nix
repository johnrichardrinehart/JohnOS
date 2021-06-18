# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

args @ { config, pkgs, ... }:
{
  virtualisation.docker.enable = true;

  nixpkgs.config.allowUnsupportedSystem = true;
  hardware.pulseaudio.enable = true;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp0s3.useDHCP = true;

  system.stateVersion = "21.05"; # Did you read the comment?

  ##### John's Stuff #####

  # Set your time zone.
  time.timeZone = "Europe/Kyiv";

  console.useXkbConfig = true;

  # Configure keymap in X11
  services.xserver = {
    enable = true;
    layout = "us";
    displayManager = {
      # https://www.reddit.com/r/unixporn/comments/a7rg63/oc_a_tiny_riceable_lightdm_greeter/eckzt15?utm_source=share&utm_medium=web2x&context=3
      defaultSession = "default"; # TODO: figure out a way to use another string besides default
      lightdm.greeters.tiny.enable = true;
      # https://discourse.nixos.org/t/opening-i3-from-home-manager-automatically/4849/8
    };
    desktopManager.session = [
      {
        manage = "window";
        name = "default";
        start = ''
                  ${pkgs.runtimeShell} $HOME/.hm-xsession &
                  waitPID=$!
          #        exec $HOME/.hm-xsession
        '';
      }
    ];
  };

  fonts.fonts = with pkgs; [ fira-code fira-code-symbols ];

  programs.zsh.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  ## consider using https://stackoverflow.com/a/54505212 for merging extraGroups
  users.users =
    let
      defaultUserAttrs = {
        isNormalUser = true;
        extraGroups = [ "wheel" "vboxsf" ]; # Enable ‘sudo’ for the user. And enable access to VBox shared folders
        shell = pkgs.zsh;
      };
    in
    {
      john = defaultUserAttrs;
      ardan = defaultUserAttrs // {
        extraGroups = defaultUserAttrs.extraGroups ++ [ "docker" ];
      };
    };


  environment.systemPackages = [
    pkgs.openconnect
  ];


  nix = {
    package = pkgs.nixUnstable;
    extraOptions =
      let
        empty_registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
      in
      "experimental-features = nix-command flakes\n" + "flake-registry = ${empty_registry}";
    registry.nixpkgs.flake = args.nixpkgs;
    nixPath = [ "nixpkgs=${args.nixpkgs}" ];
  };

  nixpkgs.config.allowUnfree = true;

  systemd.services = {
    zenimax-vpn = {
      script = ''
        ${pkgs.bash}/bin/bash -c "{ printf $(systemd-ask-password 'Zenimax password') ; printf $(systemd-ask-password 'OTP'); } | ${pkgs.openconnect}/bin/openconnect --user 'john.rinehart' --authgroup 'Contractor' 'vpn.zenimax.com' --passwd-on-stdin"
      '';
      description = "Zenimax VPN connection";
      serviceConfig = {
        Type = "simple";
        User = "root";
      };
      wantedBy = [ "default.target" ];
    };
  };


}
