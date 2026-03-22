{ config, ... }:
{
  swapDevices = [
    {
      device = "/mnt/nas/.swap";
      options = [
        "nofail"
        "x-systemd.device-timeout=${
          builtins.toString (config.system.build.literals.secondsToWaitForNAS + 1)
        }s"
      ];
      priority = 100;
    }

    {
      device = "/mnt/.swap";
      options = [
        "nofail"
        "x-systemd.device-timeout=5s"
      ];
      priority = 50;
      size = 8 * 1024;
    }
  ];

  zramSwap = {
    enable = true;
    swapDevices = 1;
    priority = 200;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 150;
  };
}
