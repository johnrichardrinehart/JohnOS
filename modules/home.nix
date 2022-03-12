args @ { config, pkgs, lib, ... }:
{
  # useful for VS Code extensions that require an auth keyring
  services.gnome.gnome-keyring.enable = true;

  nixpkgs.config.allowUnfree = true;
}
