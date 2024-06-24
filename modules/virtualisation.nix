{ ... }: {
  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
