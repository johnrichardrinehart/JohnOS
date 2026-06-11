{
  config,
  lib,
  pkgs,
  ...
}:
let
  primaryUser = config.dev.johnrinehart.users.primary;
in
{
  imports = [ ./framework.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";
  documentation.nixos.enable = false;

  dev.johnrinehart.boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };

  boot.loader = {
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };

  fonts.fontconfig.enable = lib.mkForce true;
  services.sshd.enable = true;
  programs.ssh.extraConfig = ''
    Host *
      ConnectTimeout 2
  '';
  virtualisation.containers.enable = true;

  users.users.${primaryUser}.extraGroups = [ "input" ];

  # Enable cgroup delegation for the john user's systemd user manager.
  # This is required for running Kubernetes (k3s) inside rootless Podman containers.
  # Without this, k3s fails with "failed to find cpuset cgroup (v2)" because
  # rootless containers don't have access to cgroup controllers by default.
  #
  # The Delegate= directive allows the user's systemd instance to manage its own
  # cgroup subtree, enabling proper resource isolation for containerized workloads.
  # Controllers delegated: cpu, cpuset, io, memory, pids
  #
  # Reference: https://github.com/k3d-io/k3d/issues/1439
  systemd.services."user@".serviceConfig.Delegate = "cpu cpuset io memory pids";

  dev.johnrinehart.system.enable = true;
  dev.johnrinehart.repo-manager.daemon.enable = true;

  dev.johnrinehart.agentTools = {
    enable = true;
    "oh-my-codex".enable = false;
    codexCli.statusLinePlugins = [ "codex-weekly-pace" ];
  };

  dev.johnrinehart.firmware.framework-ec.features = [ "F9-display-toggle" ];
  dev.johnrinehart.firmware.framework-ec.flashService.enable = true;

  dev.johnrinehart.desktop = {
    enable = true;
    variant = "greetd+niri";
  };
  dev.johnrinehart.voice-dictation.enable = true;
  dev.johnrinehart.sshSessionLock = {
    enable = true;
    timeoutSeconds = 60 * 15;
    suspendPromptTimeoutSeconds = 60 * 15;
    terminalMultiplexer = "tmux";
    forceInteractiveShellsIntoMultiplexer = true;
    multiplexerSessionName = "main";
  };

  dev.johnrinehart.packages.shell.enable = true;
  dev.johnrinehart.packages.editors.enable = true;
  dev.johnrinehart.packages.gui.enable = true;
  dev.johnrinehart.packages.devops.enable = true;
  dev.johnrinehart.packages.media.enable = true;
  dev.johnrinehart.packages.system.enable = true;
  dev.johnrinehart.packages.archive.enable = true;
  dev.johnrinehart.bluetooth = {
    enable = true;
    autoSuspend.enable = true;
  };

  services.fprintd.enable = true;

  dev.johnrinehart.terminal.filepicker.enable = true;
  environment.systemPackages = [
    pkgs.intel-gpu-tools
  ];
}
