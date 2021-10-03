args @ { config, pkgs, ... }:
{
  system.stateVersion = "21.05"; # Did you read the comment?
  nixpkgs.config = {
    allowUnsupportedSystem = true;
    config.allowUnfree = true;
  };

  virtualisation.docker.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Kiev";

  console.useXkbConfig = true;

  programs.zsh.enable = true;

  nix = {
    package = pkgs.nixUnstable;
    extraOptions =
      let
        empty_registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
      in
      "experimental-features = nix-command flakes\n" + "flake-registry = ${empty_registry}";
    registry.nixpkgs.flake = args.nixpkgs;
    nixPath = [ "nixpkgs=${args.nixpkgs}" ];
  };

  environment.systemPackages = [
    pkgs.git
  ];
}
