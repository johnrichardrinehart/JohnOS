# Edit this configuration file to define what should be installed on

# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

args @ { config, pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };

  nixpkgs.config.allowUnsupportedSystem = true;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;

  system.stateVersion = "21.05"; # Did you read the comment?

  ##### John's Stuff #####

  # Set your time zone.
  time.timeZone = "Europe/Kiev";

  console.useXkbConfig = true;


  networking.networkmanager.enable = true;

  # useful for VS Code extensions that require an auth keyring
  services.gnome.gnome-keyring.enable = true;
  # services.dconf.enable = true; # may be necessary for gnome-keyring... not sure

  # Configure keymap in X11
  services.xserver = {
    enable = true;
    exportConfiguration = true; # https://github.com/NixOS/nixpkgs/issues/19629#issuecomment-368051434
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
        '';
      }
    ];
  };

  fonts.fonts = let p = pkgs; in
    [
      p.fira-code
      p.fira-code-symbols
      p.font-awesome
      p.powerline-fonts
      p.powerline-symbols
      (p.nerdfonts.override { fonts = [ "DroidSansMono" ]; })
    ];

  programs.zsh.enable = true;
  programs.adb.enable = true; # droidcam

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
        hashedPassword = "$6$Ao7vxO2e5CHZ$QyJE9UHOUem41VHskn6bbuUdeLZFOFGLCVM0S.UmJWFooaXa3a3Nw.3NFZqklfqMGTfPXlJKIx.9xVcM3k6Z3/";
      };
      ardan = defaultUserAttrs // {
        hashedPassword = "$6$GjNHUPIRR981Cov$TNQYuTmnGSvUMotD.dUqJ7c9dLCJi0hWL7ztsw1icJovNNjO1eA9vNH9ZXmQR0eaBVPgGrsaXAr/c8YouFhtY.";
      };
    };

  environment.systemPackages =
    [
      pkgs.openconnect
      pkgs.alsa-tools # https://askubuntu.com/a/1293623
      pkgs.glxinfo

      # https://github.com/VTimofeenko/home-manager/blob/3d9ea6d74ee511cd8664f4a486ce65bd39e03ea8/experiments/homed.nix
      (pkgs.systemd.override (old: {
        withHomed = true;
      }))
    ];


  nix = {
    package = args.nix_pkg;

    settings = {
      substituters = [
        "https://johnos.cachix.org"
      ];

      trusted-public-keys = [
        "johnos.cachix.org-1:wwbcQLNTaO9dx0CIXN+uC3vFl8fvhtkJbZWzMXWLFu0="
      ];
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

  nixpkgs.config.allowUnfree = true;
}
