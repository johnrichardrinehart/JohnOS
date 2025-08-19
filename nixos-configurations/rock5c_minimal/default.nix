{ ... }:
{
  nixpkgs.hostPlatform = "aarch64-linux";
  networking.hostName = "rock5c-minimal";
  dev.johnrinehart.rock5c.enable = true;
  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.nix.enable = true;

  services.deluge = {
    web.enable = true;
    enable = true;
    openFilesLimit = 1048576; # 1<<20 = 2^20 = 1048576
  };

  services.jellyfin = {
    openFirewall = true;
    enable = true;
  };
}
