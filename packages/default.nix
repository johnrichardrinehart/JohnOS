# Custom packages for JohnOS
{ pkgs }:

let
  rock5cFlashImage = pkgs.callPackage ../nixos-modules/rock5c/flash-image.nix { };
  flashRock5cSd = pkgs.writeShellScriptBin "flash-rock5c-sd" ''
    exec ${rock5cFlashImage}/bin/rock5c-flash-image --target-type sd "$@"
  '';
  flashRock5cEmmc = pkgs.writeShellScriptBin "flash-rock5c-emmc" ''
    exec ${rock5cFlashImage}/bin/rock5c-flash-image --target-type emmc "$@"
  '';
in
{
  rock5c-flash-image = rock5cFlashImage;
  flash-rock5c-sd = flashRock5cSd;
  flash-rock5c-emmc = flashRock5cEmmc;
}
