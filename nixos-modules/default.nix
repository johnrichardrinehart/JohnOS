{ inputs, lib, ... }:
{
  config._module.args.inputs = lib.mkDefault inputs;

  options.dev.johnrinehart.users = {
    primary = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z_][A-Za-z0-9_-]*";
      default = "john";
      example = "jrinehart";
      description = ''
        Primary login user for JohnOS system and Home Manager configuration.
      '';
    };
  };

  imports = [
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.default

    (
      { config, pkgs, ... }:
      {
        config =
          lib.mkIf (config.dev.johnrinehart.s3_mount.enable || config.dev.johnrinehart.gocryptfs.enable)
            {
              # The s3fs and gocryptfs modules use filesystem types like
              # fuse./nix/store/.../bin/s3fs. This patched mount helper lookup is
              # required for store paths with multiple periods.
              systemd.package = pkgs.systemd.override {
                util-linux = pkgs.dev.johnrinehart.util-linux;
              };
            };
      }
    )

    ./agent-tools.nix
    ./auto-suspend.nix
    ./bluetooth.nix
    ./hibernate-resume-optimization.nix
    ./droidcam.nix
    ./filepicker.nix
    ./firmware/framework-ec.nix
    ./fonts.nix
    ./gocryptfs.nix
    ./ide.nix
    ./laptop.nix
    ./locale.nix
    ./network.nix
    ./nix.nix
    ./packages.nix
    ./repo-manager.nix
    ./s3_mount.nix
    ./sound.nix
    ./ssh.nix
    ./ssh-session-lock.nix
    ./system.nix
    ./thunderbolt-debug.nix
    ./tmux.nix
    ./tmux-socket.nix
    ./virtualisation.nix
    ./voice-dictation.nix

    ./desktop/default.nix
    ./desktop/hyprland.nix
    ./desktop/greetd+niri.nix
    ./desktop/xmonad.nix
    ./desktop/xorg-xmonad.nix
    ./desktop/xorg.nix

    ./bootloader
    ./kernel
  ];
}
