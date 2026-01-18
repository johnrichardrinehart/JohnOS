{ lib, pkgs, ... }:
{
  imports = [ ./framework.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";

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
  virtualisation.containers.enable = true;

  users.users.john.extraGroups = [ "input" ];

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
  dev.johnrinehart.desktop = {
    enable = true;
    variant = "greetd+niri";
  };

  dev.johnrinehart.packages.shell.enable = true;
  dev.johnrinehart.packages.editors.enable = true;
  dev.johnrinehart.packages.gui.enable = true;
  dev.johnrinehart.packages.devops.enable = true;
  dev.johnrinehart.packages.media.enable = true;
  dev.johnrinehart.packages.system.enable = true;
  dev.johnrinehart.packages.archive.enable = true;

  services.fprintd.enable = true;

  dev.johnrinehart.terminal.filepicker.enable = true;
}
