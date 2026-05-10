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
  ecImage = "${pkgs.framework-ec}/${pkgs.framework-ec.imagePath or "share/framework-ec/hx20/ec.bin"}";
  frameworkEcFlash = lib.getExe pkgs.framework-ec-flash;
  expectedDmiBoardName = if flashCfg.expectedDmiBoardName == null then "" else flashCfg.expectedDmiBoardName;
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
        automatically flash pkgs.framework-ec when the live EC contents differ
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
    nixpkgs.overlays = lib.mkIf hasF9DisplayToggle (lib.mkAfter [
      (final: prev: {
        framework-ec = prev.framework-ec.override {
          rev = "553827caae7134d45a0617af9c201e333eab9a26";
          hash = "sha256-lqWFUxelwYABTf8FSyqL+X8CeGW/2zjeZvxHI1ZUuWM=";
          supportsDisplayToggleKeyHid = true;
          patches = [
            # Make Framework F9's Project action emit a HID display-toggle event
            # instead of the layout-dependent Win+P keyboard chord that collides
            # with niri Mod+L on Dvorak.
            (final.fetchpatch2 {
              url = "https://patch-diff.githubusercontent.com/raw/FrameworkComputer/EmbeddedController/pull/49.patch";
              hash = "sha256-wJJ244u6oT+ZsGwiD+15UcspR1F/bu4mOOj9Qh5qgoc=";
            })
            ../../packages/framework-ec-display-toggle-key-hid-persistent.patch
          ];
        };
      })
    ]);

    environment.systemPackages = lib.mkIf (cfg.features != [ ] || flashCfg.enable) [
      pkgs.framework-ec
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
        ${frameworkEcFlash} --yes --include-ro ${lib.escapeShellArg ecImage}
      '';
    };
  };
}
