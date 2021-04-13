{autologinUser ? "demo", ...}:
{config, pkgs, ...}:
{
	environment.systemPackages = with pkgs; [
		st
	];
	services.xserver.enable = true;
	services.xserver.resolutions = [ { x = 1920; y = 1080; } ];
	services.xserver.libinput.enable = true;
#services.xserver.displayManager.startx.enable = true;
	services.xserver.layout = "us";
	services.xserver.xkbVariant = "dvorak";
	services.xserver.displayManager.defaultSession = "none+dwm";
	services.xserver.windowManager.dwm.enable = true;
	services.xserver.displayManager.autoLogin.enable = true;
	services.xserver.displayManager.autoLogin.user = autologinUser;
	services.acpid.handlers = {
		dim = {
			event = "video/brightnessdown";
			action = ''
DISPLAY=:0 \
XAUTHORITY=/home/john/.Xauthority \
${pkgs.bash}/bin/sh -c "${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --brightness 0.2" john
				'';

		};
		brighten = {
			event = "video/brightnessup";
			action = ''
DISPLAY=:0 \
XAUTHORITY=/home/john/.Xauthority \
${pkgs.bash}/bin/sh -c "${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --brightness 0.8" john
				'';
		};
	};
	services.acpid.enable = true;
	services.acpid.logEvents = true;
}
