# Custom packages for JohnOS
{ pkgs }:

{
  agent-deck = pkgs.callPackage ./agent-deck.nix { };
}
