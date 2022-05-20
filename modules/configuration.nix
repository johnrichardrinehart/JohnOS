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

  system.stateVersion = "21.05"; # Did you read the comment?

  ##### John's Stuff #####

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";
  # time.timeZone = "America/Los_Angeles";

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
    # layout = "us";
    displayManager = {
      # https://www.reddit.com/r/unixporn/comments/a7rg63/oc_a_tiny_riceable_lightdm_greeter/eckzt15?utm_source=share&utm_medium=web2x&context=3
      defaultSession = "default"; # TODO: figure out a way to use another string besides default
      lightdm.greeters.enso.enable = true;
      lightdm.extraConfig = ''
        logind-check-graphical = true
      '';

      sessionCommands =
        let
          laptopResolution = "2256x1504";
        in
        ''
            configureKeyboards() {
            ################################################################################
            ########## Useful URLs from research
            ################################################################################
            # https://www.in-ulm.de/~mascheck/X11/xmodmap.html
            # https://wiki.archlinux.org/title/Xorg/Keyboard_configuration#Using_X_configuration_files
            # https://askubuntu.com/a/337431
            #
            ################################################################################
            ########## Helpful commands to find the keyboard map
            ################################################################################
            # setxkbmap -query
            # input list-props $NUMBER_YOURE_INTERESTED_IN
            # localctl list-x11-keymap models
            #
            #  setxkbmap -model sun_type7_usb -layout gb -option ctrl:swapcaps
            #  setxkbmap -model pc104 -layout cz,us -variant ,dvorak -option grp:alt_shift_toggle
            #  localectl [--no-convert] set-x11-keymap layout [model [variant [options]]]

              LAPTOP_KBD="AT Translated Set 2 keyboard"; LAPTOP_KBD_ID=$(${pkgs.xorg.xinput}/bin/xinput | grep "''${LAPTOP_KBD}" | cut -f 2 | cut -d = -f 2); ${pkgs.xorg.setxkbmap}/bin/setxkbmap -device $LAPTOP_KBD_ID -layout dvorak
              }

            configureMonitors() {
            LAP_MONITOR="eDP-1"
            ${pkgs.xorg.xrandr}/bin/xrandr --output "''${LAP_MONITOR}" --mode ${laptopResolution}
            ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource 1 0

          # looks like: https://bugs.freedesktop.org/show_bug.cgi?id=110830
          # which referencese: https://gist.github.com/szpak/71081b40217fb27c7a565b8c7b972067
          # consider filing a bug at: https://gitlab.freedesktop.org/drm/nouveau/
            for monitor in $(${pkgs.xorg.xrandr}/bin/xrandr | grep " connected" | cut -f1 -d " "); do
            if [[ "''${monitor}" != "''${LAP_MONITOR}" ]]
            then
              ${pkgs.xorg.xrandr}/bin/xrandr --output "''${monitor}" --mode 2560x1440 --primary --above "''${LAP_MONITOR}"
            fi
            done
            }

            configureKeyboards
            configureMonitors
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

  environment.systemPackages =
    let
      p = pkgs;
    in
    [
      p.openconnect
      p.alsa-tools # https://askubuntu.com/a/1293623
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
      # language tools
      p.jq
      p.nixpkgs-fmt
      # os tools
      p.htop
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
      p.go_1_17
      p.gcc
      # communication tools
      p.droidcam
      # multimedia tools
      p.playerctl
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


