{ config, lib, ... }:
let
  blacklistText = lib.concatMapStrings (name: "blacklist ${name}\n") config.boot.blacklistedKernelModules;
  extraLines = lib.filter (line: line != "") (lib.splitString "\n" config.boot.extraModprobeConfig);
  extraText = lib.concatStringsSep "\n\n" extraLines;
in
{
  environment.etc."modprobe.d/nixos.conf".text = lib.mkForce (
    blacklistText
    + "\n"
    + extraText
    + "\n\n\n\n"
  );
}
