{ config, pkgs, ... }:
rec {
  systemd = {
    package = pkgs.systemd.override {
      withHomed = true;
    };
  };
  environment.systemPackages = with pkgs; [
    tmux
    vim
    pavucontrol
  ];
}
