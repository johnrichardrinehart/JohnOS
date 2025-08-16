{ pkgs, ... }:
{
  fonts.packages = [
    pkgs.fira-code
    pkgs.fira-code-symbols
    pkgs.font-awesome
    pkgs.powerline-fonts
    pkgs.powerline-symbols
    pkgs.nerd-fonts.droid-sans-mono
  ];
}
