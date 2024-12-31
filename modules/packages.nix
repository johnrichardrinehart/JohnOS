{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.dev.johnrinehart.systemPackages;
in
{
  options.dev.johnrinehart.systemPackages = {
    enable = lib.mkEnableOption "John's systemPackages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.pciutils
      pkgs.openconnect
      pkgs.alsa-tools # https://askubuntu.com/a/1293623
      pkgs.alsa-utils # https://askubuntu.com/a/1293623
      pkgs.glxinfo
      # editors
      pkgs.vim
      pkgs.helix
      pkgs.neovim
      # gui configuration
      pkgs.feh
      pkgs.multilockscreen
      pkgs.dconf
      pkgs.dunst
      pkgs.libnotify
      pkgs.gnome-icon-theme
      # gui apps
      pkgs.rofi
      #pkgs.slack
      pkgs.vscodium
      #pkgs.vscode
      pkgs.brave
      pkgs.flameshot
      pkgs.keepassxc
      pkgs.stalonetray
      #pkgs.peek # GIF/webp screen recording
      pkgs.mpv # mplayer replacement
      pkgs.simplescreenrecorder
      # shell tools
      pkgs.powerline-rs
      pkgs.oil
      pkgs.ranger
      pkgs.jump
      pkgs.tmux
      pkgs.xdg-utils # `open`
      pkgs.xclip
      pkgs.fd
      pkgs.bc # needed for adjusting screen brightness
      pkgs.libqalculate
      pkgs.ncdu # ncurses disk usage (tree+du, basically)
      pkgs.dive # docker image analyzer
      pkgs.xsel
      pkgs.ripgrep
      pkgs.fzf
      # language tools
      pkgs.gnumake
      pkgs.jq
      pkgs.nixpkgs-fmt
      pkgs.tokei
      ## rust stuff
      # os tools
      pkgs.dig
      pkgs.htop
      pkgs.tree
      pkgs.killall
      pkgs.lsof
      pkgs.pstree
      pkgs.nethogs
      pkgs.pavucontrol
      pkgs.autorandr
      pkgs.file
      pkgs.pv # useful for dd operations (e.g. `dd if=infile | pv | sudo dd of=outfile bs=512`)
      # archive tools
      pkgs.zip
      pkgs.unzip
      # programming languages
      pkgs.go_1_21
      pkgs.gcc
      # communication tools
      pkgs.obs-studio
      # multimedia tools
      pkgs.pulseaudioFull
      pkgs.playerctl
      # DevOps tools
      pkgs.minikube
      pkgs.kubectl
      # browsers
      pkgs.libxml2 # needed for alias lkv
      # media
      pkgs.ffmpeg_7-full
      # stuff for lunarvim :(
      pkgs.python3
      pkgs.python39Packages.pip
      pkgs.hunspellDicts.en-us
      pkgs.ntfs3g
      pkgs.gparted
      pkgs.deluge
      pkgs.wirelesstools
      pkgs.usbutils
      # terminal stuff
      pkgs.zellij
    ];
  };
}
