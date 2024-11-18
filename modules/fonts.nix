{ pkgs, ... }:
{
  fonts.packages = [
    pkgs.fira-code
    pkgs.fira-code-symbols
    pkgs.font-awesome
    pkgs.powerline-fonts
    pkgs.powerline-symbols
    (pkgs.nerdfonts.override { fonts = [ "DroidSansMono" ]; })
  ];
}
