{config, pkgs, ...}:
{
	environment.systemPackages = with pkgs; [
        tmux
        vim
        st
    ];
}