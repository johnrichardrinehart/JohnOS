{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.network;
in
{
  options = {
    dev.johnrinehart.network = {
      enable = lib.mkEnableOption "John's opinionated network config";
      manager = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "networkmanager"
            "iwd"
          ]
        );
        default = null;
        description = "Wireless network manager to configure.";
      };
      migrateLegacyConfigs = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Import known legacy Wi-Fi profiles into the selected manager during activation.";
      };
      preservePredictableInterfaceNames = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Keep path-based wireless interface names when iwd is selected.";
      };
      tools.enable = lib.mkEnableOption "wireless diagnostic and manager frontend tools";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      dev.johnrinehart.network.manager = lib.mkDefault "networkmanager";
      services.tailscale.enable = true;

      networking.nameservers = [
        "1.1.1.1"
        "8.8.8.8"
        "6.6.6.6"
      ];
      networking.resolvconf.enable = true;
      networking.wireless.enable = lib.mkDefault false;
    })

    (lib.mkIf (cfg.enable || cfg.manager != null) {
      dev.johnrinehart.network.tools.enable = lib.mkDefault true;

      environment.systemPackages = lib.mkIf cfg.tools.enable [
        pkgs.iw
      ];
    })

    (lib.mkIf (cfg.manager == "networkmanager") {
      networking.networkmanager.enable = true;
      networking.networkmanager.unmanaged = [ "tailscale0" ];

      environment.systemPackages = [
        pkgs.dev.johnrinehart.legacy-network-configs.toNetworkManager
      ]
      ++ lib.optionals cfg.tools.enable [
        pkgs.wifitui
      ];

      system.activationScripts.importLegacyNetworkConfigsToNetworkManager = lib.mkIf cfg.migrateLegacyConfigs ''
        ${pkgs.dev.johnrinehart.legacy-network-configs.toNetworkManager}/bin/legacy-network-configs-to-nm
      '';
    })

    (lib.mkIf (cfg.manager == "iwd") {
      networking.dhcpcd.enable = lib.mkForce false;
      networking.networkmanager.enable = lib.mkForce false;
      networking.wireless.iwd = {
        enable = true;
        settings = {
          General.EnableNetworkConfiguration = true;
          Network.NameResolvingService = "resolvconf";
          Settings.AutoConnect = true;
          DriverQuirks.DefaultInterface = "?*";
        };
      };

      systemd.network.links."80-iwd".linkConfig.NamePolicy =
        lib.mkIf cfg.preservePredictableInterfaceNames (lib.mkForce "path");

      environment.systemPackages = [
        pkgs.dev.johnrinehart.legacy-network-configs.toIwd
      ]
      ++ lib.optionals cfg.tools.enable [
        pkgs.impala
      ];

      system.activationScripts.importLegacyNetworkConfigsToIwd = lib.mkIf cfg.migrateLegacyConfigs ''
        ${pkgs.dev.johnrinehart.legacy-network-configs.toIwd}/bin/legacy-network-config-to-iwd
      '';
    })
  ];
}
