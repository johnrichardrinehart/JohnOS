{ ... }:
{
  imports = [
    ../desktop.nix
    inputs.home-manager.nixosModules.default
    ({ hardware.enableRedistributableFirmware = true; })
    (
      { lib, ... }:
      {
        dev.johnrinehart = {
          sound.enable = true;
          kernel.latest.enable = true;
          network.enable = true;
          systemPackages.enable = true;
          xmonad.enable = true;
          bluetooth.enable = true;
        };
      }
    )
    (
      { lib, ... }:
      {
        nixpkgs = {
          hostPlatform = lib.mkDefault "x86_64-linux";
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [
              "electron-25.9.0"
            ];
            allowUnsupportedSystem = true;
          };
        };
      }
    )
    (
      { pkgs, ... }:
      {
        nix = {
          registry = {
            nixpkgs.flake = inputs.nixpkgs;
            templates.flake = inputs.flake-templates;
          };

          package = pkgs.nix;

          settings.trusted-users = [ "john" ];

          extraOptions =
            let
              empty_registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
            in
            ''
              experimental-features = nix-command flakes
              flake-registry = ${empty_registry}
            '';
          nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
        };
      }
    )
    (
      { pkgs, ... }:
      {
        nixpkgs.overlays = [
          (final: prev: {
            util-linux = prev.util-linux.overrideAttrs (old: {
              patches = old.patches ++ [ ../patches/util-linux.patch ];
            });
          })
        ];
      }
    )
    (
      { ... }:
      {
        imports = [ inputs.sops-nix.nixosModules.default ];
      }
    )
  ];
}
