# Edit this configuration file to define what should be installed on

# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

args @ { config, pkgs, lib, ... }:
{
  imports = [ ./home.nix ];

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };

  nixpkgs.config.allowUnsupportedSystem = true;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;

  system.stateVersion = "22.05"; # Did you read the comment?

  ##### John's Stuff #####

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";

  console.useXkbConfig = true;

  networking.networkmanager.enable = true;
  networking.wireless.enable = false;
  networking.extraHosts = ''
    45.63.61.99 mongoloid
  '';

  # useful for VS Code extensions that require an auth keyring
  services.gnome.gnome-keyring.enable = true;

  # Configure keymap in X11
  services.xserver = {
    enable = true;
    exportConfiguration = true; # https://github.com/NixOS/nixpkgs/issues/19629#issuecomment-368051434
    displayManager = {
      # https://www.reddit.com/r/unixporn/comments/a7rg63/oc_a_tiny_riceable_lightdm_greeter/eckzt15?utm_source=share&utm_medium=web2x&context=3
      defaultSession = "default"; # TODO: figure out a way to use another string besides default
      lightdm.greeters.enso.enable = true;
      lightdm.extraConfig = ''
        logind-check-graphical = true
      '';
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

  nixpkgs.overlays = import ./overlays.nix;

  environment.systemPackages =
    let
      p = pkgs;
    in
    [
      p.openconnect
      p.alsa-tools # https://askubuntu.com/a/1293623
      p.alsa-utils # https://askubuntu.com/a/1293623
      p.glxinfo
      p.vim
      # gui configuration
      p.feh
      p.multilockscreen
      p.dconf
      p.dunst
      p.libnotify
      p.gnome-icon-theme
      # gui apps
      p.rofi
      p.slack
      p.vscodium
      p.brave
      p.flameshot
      p.keepassxc
      p.dbeaver
      p.stalonetray
      p.peek # GIF/webp screen recording
      p.mpv # mplayer replacement
      p.simplescreenrecorder
      p.obsidian
      # shell tools
      p.powerline-rs
      p.oil
      p.ranger
      p.jump
      p.tmux
      p.xdg-utils # `open`
      p.xclip
      p.fd
      p.bc # needed for adjusting screen brightness
      p.libqalculate
      p.ncdu # ncurses disk usage (tree+du, basically)
      p.dive # docker image analyzer
      p.xsel
      # language tools
      p.jq
      p.nixpkgs-fmt
      # os tools
      p.dig
      p.btop
      p.tree
      p.killall
      p.lsof
      p.pstree
      p.nethogs
      p.pavucontrol
      p.autorandr
      p.file
      p.pv # useful for dd operations (e.g. `dd if=infile | pv | sudo dd of=outfile bs=512`)
      # archive tools
      p.zip
      p.unzip
      # programming languages
      p.go_1_18
      p.gcc
      # communication tools
      p.droidcam
      p.obs-studio
      # multimedia tools
      p.pulseaudioFull
      p.playerctl
      # DevOps tools
      p.minikube
      p.kubectl
      # browsers
      p.libxml2 # needed for alias lkv
    ];

  nix = {
    package = args.nix;

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

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.config.allowUnfree = true;

  # networking.hostName = "JohnOS-framework"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.wireless.userControlled.enable = true;
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
}

