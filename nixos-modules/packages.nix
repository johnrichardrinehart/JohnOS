{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.dev.johnrinehart.packages;
in
{
  options.dev.johnrinehart.packages = {
    shell.enable = lib.mkEnableOption "Shell tools (zoxide, tmux, fzf, ripgrep, fd, etc.)";
    editors.enable = lib.mkEnableOption "Text editors (vim)";
    gui.enable = lib.mkEnableOption "GUI apps (brave, vscodium, keepassxc, etc.)";
    devops.enable = lib.mkEnableOption "DevOps tools (minikube, kubectl)";
    media.enable = lib.mkEnableOption "Media tools (mpv, ffmpeg, obs-studio, etc.)";
    system.enable = lib.mkEnableOption "System utilities (htop, tree, lsof, etc.)";
    archive.enable = lib.mkEnableOption "Archive tools (zip, unzip)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.shell.enable {
      environment.systemPackages = [
        pkgs.zoxide
        pkgs.dev.johnrinehart.tmux
        pkgs.xdg-utils
        pkgs.fd
        pkgs.ripgrep
        pkgs.fzf
        pkgs.jq
        pkgs.bc
        pkgs.htop
        pkgs.tree
        pkgs.git
        pkgs.dev.johnrinehart.repo-manager
      ];
    })

    (lib.mkIf cfg.editors.enable {
      environment.systemPackages = [
        pkgs.vim
      ];
    })

    (lib.mkIf cfg.gui.enable {
      environment.systemPackages = [
        pkgs.dconf
        pkgs.libnotify
        pkgs.gnome-icon-theme
        pkgs.vscodium
        pkgs.brave
        pkgs.keepassxc
        pkgs.pavucontrol
        pkgs.gparted
      ];
    })

    (lib.mkIf cfg.devops.enable {
      environment.systemPackages = [
        pkgs.kubectl
      ];
    })

    (lib.mkIf cfg.media.enable {
      environment.systemPackages = [
        pkgs.mpv
        pkgs.simplescreenrecorder
        pkgs.obs-studio
        pkgs.playerctl
        pkgs.ffmpeg_7-full
        pkgs.deluge
      ];
    })

    (lib.mkIf cfg.system.enable {
      environment.systemPackages = [
        pkgs.pciutils
        pkgs.usbutils
        pkgs.wirelesstools
        pkgs.alsa-tools
        pkgs.alsa-utils
        pkgs.dig
        pkgs.tree
        pkgs.killall
        pkgs.lsof
        pkgs.pstree
        pkgs.nethogs
        pkgs.file
        pkgs.pv
        pkgs.ncdu
        pkgs.ntfs3g
        pkgs.libqalculate
        pkgs.tokei
        pkgs.libxml2
        pkgs.openconnect
      ];
    })

    (lib.mkIf cfg.archive.enable {
      environment.systemPackages = [
        pkgs.zip
        pkgs.unzip
      ];
    })
  ];
}
