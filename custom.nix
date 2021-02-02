{config, pkgs, ...}:
{
	isoImage.makeEfiBootable=true;

	networking.hostName = "mynixos";

	environment.systemPackages = with pkgs; [ tmux vim ];
	users.extraUsers.root.password = "somepassword";
}