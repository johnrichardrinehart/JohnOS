{config, pkgs, ...}:
{
    environment.systemPackages = with pkgs; [ st ];
    services.xserver.enable = true;
    services.xserver.displayManager.startx.enable = true;
    services.xserver.windowManager.dwm.enable = true;
    services.xserver.layout = "us";
    services.xserver.variant = "dvorak";
    services.xserver.displayManager.defaultSession = "none+dwm";
    services.xserver.displayManager.autoLogin.enable = true;
    services.xserver.displayManager.autoLogin.user = "root";
}