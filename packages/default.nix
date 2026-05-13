# Custom packages for JohnOS
{ pkgs }:

{
  inherit (pkgs) agent-deck;
  inherit (pkgs) codex-weekly-pace;
  inherit (pkgs) codex-cli-nix;
  inherit (pkgs) framework-ec;
  inherit (pkgs) framework-ec-flash;
  inherit (pkgs) herdr;
  "niri-26.04" = pkgs."niri-26.04";
  inherit (pkgs) omx-agent-tools;
  inherit (pkgs) oh-my-codex;
}
