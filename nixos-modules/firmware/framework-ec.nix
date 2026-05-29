{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dev.johnrinehart.firmware.framework-ec;
  flashCfg = cfg.flashService;
  hasFeature = feature: builtins.elem feature cfg.features;
  hasF9DisplayToggle = hasFeature "F9-display-toggle";
  frameworkEc =
    if hasF9DisplayToggle then
      pkgs.dev.johnrinehart.framework-ec.override {
        rev = "f6620a8200e8d1b349078710b271540b5b8a1a18";
        hash = "sha256-0raKJJug3T22XV1sX0nwIjx4ZOKlI3uoyLYOlMGdI/I=";
        supportsDisplayToggleKeyHid = true;
        patches = [
          # Make Framework F9's Project action emit a HID display-toggle event
          # instead of the layout-dependent Win+P keyboard chord that collides
          # with niri Mod+L on Dvorak.
          (pkgs.fetchpatch2 {
            url = "https://patch-diff.githubusercontent.com/raw/FrameworkComputer/EmbeddedController/pull/49.patch";
            hash = "sha256-Z1xFZ1iYREAA72TjMZLJtLQuN0HikzFyz/MmuLqZgG4=";
          })
          ../../packages/framework-ec/framework-ec-display-toggle-key-hid-persistent.patch
        ];
      }
    else
      pkgs.dev.johnrinehart.framework-ec;
  frameworkEcFlashPackage = pkgs.dev.johnrinehart.framework-ec-flash.override {
    framework-ec = frameworkEc;
  };
  ecImage = "${frameworkEc}/${frameworkEc.imagePath or "share/framework-ec/hx20/ec.bin"}";
  frameworkEcFlash = lib.getExe frameworkEcFlashPackage;
  expectedDmiBoardName =
    if flashCfg.expectedDmiBoardName == null then "" else flashCfg.expectedDmiBoardName;
  requireAC = if flashCfg.requireAC then "1" else "0";
in
{
  options.dev.johnrinehart.firmware.framework-ec = {
    features = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "F9-display-toggle" ]);
      default = [ ];
      example = [ "F9-display-toggle" ];
      description = ''
        Framework EC features to enable in the configured firmware image.

        Feature selection controls which firmware patches are applied and which
        host-side runtime tools/services are exposed.
      '';
    };

    flashService = {
      enable = lib.mkEnableOption ''
        automatically flash the scoped Framework EC package when the live EC contents differ
      '';

      requireAC = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Require mains power before automatically flashing the Framework EC.
        '';
      };

      expectedDmiBoardName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "FRANBMCP0A";
        description = ''
          DMI board_name that must match before automatic EC flashing runs.
          Set to null to disable this guard.
        '';
      };
    };
  };

  config = {
    environment.systemPackages = lib.mkIf (cfg.features != [ ] || flashCfg.enable) [
      frameworkEc
      pkgs.framework-tool
    ];

    systemd.services.framework-ec-flash = lib.mkIf flashCfg.enable {
      description = "Flash configured Framework EC firmware if needed";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      wants = [ "systemd-udev-settle.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        NotifyAccess = "all";
        StateDirectory = "framework-ec-flash";
      };

      script = ''
        set -eu

        export FRAMEWORK_EC_FLASH_EXPECTED_DMI_BOARD_NAME=${lib.escapeShellArg expectedDmiBoardName}
        export FRAMEWORK_EC_FLASH_REQUIRE_AC=${lib.escapeShellArg requireAC}
        export FRAMEWORK_EC_FLASH_POWER_REFUSAL_EXIT_CODE=0
        ${frameworkEcFlash} --yes ${lib.escapeShellArg ecImage}
      '';
    };
  };
}
