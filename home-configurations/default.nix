inputs:
let
  lib = inputs.nixpkgs.lib;
  home-manager = inputs.home-manager;
in
{
  # Add home-manager configurations here
  # Example:
  # john = home-manager.lib.homeManagerConfiguration {
  #   pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  #   modules = [ ./john.nix ];
  # };
}