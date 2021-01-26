{config, pkgs, ...}:
{
    services.xserver.enable = true;
    services.xserver.displayManager.startx.enable = true;
    services.xserver.windowManager.dwm.enable = true;
}