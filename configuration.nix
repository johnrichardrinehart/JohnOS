# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

args @ { config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

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
    xkbVariant = "dvorak";
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
  users.users =
    let
      defaultUserAttrs = {
        isNormalUser = true;
        extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
        shell = pkgs.zsh;
      };
    in
    {
      john = defaultUserAttrs;
      ardan = defaultUserAttrs;
    };


  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    args.agenix.defaultPackage.x86_64-linux
  ];

  age.sshKeyPaths = [ "/home/john/.ssh/id_rsa" "/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets.secret1 = {
    file = ./secrets/secret1.age;
    owner = "john";
  };


  virtualisation.virtualbox.guest.enable = true;

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

}
