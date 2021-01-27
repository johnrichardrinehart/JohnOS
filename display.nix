{config, pkgs, ...}:
{
    environment.systemPackages = with pkgs; [ st ];
    services.xserver.enable = true;
    services.xserver.displayManager.startx.enable = true;
    services.xserver.windowManager.dwm.enable = true;
}