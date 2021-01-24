{config, pkgs, ...}:
{
    services.xserver.displayManager.lightdm.enable = false;
    services.xserver.displayManager.startx.enable = true;
    services.xserver.windowManager.dwm.enable = true;
}