{config, pkgs, ...}:
{
	isoImage.makeEfiBootable=true;

	networking.hostName = "mynixos";
	services.nginx.enable=true;
	environment.systemPackages = with pkgs; [ tmux vim ];
	users.extraUsers.root.password = "somepassword";
}