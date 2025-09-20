{ config, ... }:
{
  swapDevices = [
    {
      device = "/mnt/nas/.swap";
      options = [
        "nofail"
        # according to dmesg this is ignored by systemd, keeping so that the message
        # about ignoring these options keeps appearing in dmesg so that I can one day
        # get around to figuring out what's going on since it should be supported (cf.
        # https://www.freedesktop.org/software/systemd/man/253/systemd.swap.html)....
        "x-systemd.device-timeout=${
          builtins.toString (config.system.build.literals.secondsToWaitForNAS + 1)
        }s"
      ];
      priority = 100;
    }

    {
      device = "/mnt/.swap"; # on rootfs
      options = [
        "nofail"
        # according to dmesg this is ignored by systemd, keeping so that the message
        # about ignoring these options keeps appearing in dmesg so that I can one day
        # get around to figuring out what's going on since it should be supported (cf.
        # https://www.freedesktop.org/software/systemd/man/253/systemd.swap.html)....
        "x-systemd.device-timeout=5s" # maybe should be less time - we'll see
      ];
      priority = 50;
      size = 8 * 1024; # 8 GB - an emergency kind of thing
    }
  ];

  zramSwap = {
    enable = true;
    swapDevices = 1; # default, but want to ensure
    priority = 200;
    memoryPercent = 50; # TODO: update based on measurements
    algorithm = "zstd"; # default, but want to make sure it's used
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 150;
  };

}
