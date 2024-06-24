{ ... }: {
  console.useXkbConfig = true;
  services.xserver.xkb.variant = "dvorak";
  time.timeZone = "America/Los_Angeles";
}

