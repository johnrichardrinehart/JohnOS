args @ { config, pkgs, lib, ... }: {
  boot.loader.systemd-boot.configurationLimit = 20;

  imports = [ ./home.nix ];

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  #nixpkgs.config.allowUnsupportedSystem = true;

  ##### John's Stuff #####
  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

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

  fonts.packages = let p = pkgs; in
    [
      p.fira-code
      p.fira-code-symbols
      p.font-awesome
      p.powerline-fonts
      p.powerline-symbols
      (p.nerdfonts.override { fonts = [ "DroidSansMono" ]; })
      #p.comic-mono
    ];

  programs.adb.enable = true; # droidcam

  environment.systemPackages =
    let
      p = pkgs;
    in
    [
      p.pciutils
      p.openconnect
      p.alsa-tools # https://askubuntu.com/a/1293623
      p.alsa-utils # https://askubuntu.com/a/1293623
      p.glxinfo
      # editors
      p.vim
      p.helix
      p.neovim
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
      #p.vscode
      p.brave
      p.flameshot
      p.keepassxc
      p.dbeaver
      p.stalonetray
      #p.peek # GIF/webp screen recording
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
      p.ripgrep
      p.fzf
      # language tools
      p.gnumake
      p.jq
      p.nixpkgs-fmt
      p.tokei
      ## rust stuff
      # os tools
      p.dig
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
      p.go_1_21
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
      # media
      p.ffmpeg_5-full
      # stuff for lunarvim :(
      p.python3
      p.python39Packages.pip
      p.hunspellDicts.en-us
      p.ntfs3g
      p.gparted
      p.deluge
      p.wirelesstools
      p.usbutils
      p.whatsapp-for-linux
      # terminal stuff
      p.zellij
    ];
}
