{
  inputs = {
    # the commit right before it was fixed in nixos-unstable (a1efaf3eb8ae0f730428fbd503008d65ee8829e1)
    nixpkgs.url = "github:NixOS/nixpkgs/bdfe187ba675c680deb89d8d7f1a0f583626f08d";

    home-manager = {
      url = "github:nix-community/home-manager/release-21.11";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    let
      user = "john";

      lib = inputs.nixpkgs.lib;

      nixosConfigurationConstructor = { flavor, sha }:
        inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            inputs.home-manager.nixosModules.home-manager
            {
              config = {
                home-manager = {
                  useUserPackages = true;
                  users.${user} = ./${user}.nix;
                  extraSpecialArgs = { inherit flavor sha; };
                };
              };
            }
          ];

          specialArgs = { inherit flavor sha; };
        };

      longSha = "a9660fcf5c3f9b7ce132d78652b80abf9d557342c7b3f81fdce1192648d88b5c";
      suggestedSha = "sha256-fJs/XM8PZqm/CrhShtcy4R/4s8dCc1WdXIvYSCYZ4dw=";

      tackOn = x: map (l: l // x);

      globalFlavors = [ "globalOverride" "globalOverlay" ];
      hmFlavors = [ "hmOverride" "hmOverlay" ];

      flavors =
        tackOn { attrPath = "pkgs.dbeaver"; } (map (el: { name = el; }) globalFlavors) ++
        tackOn { attrPath = "home-manager.users.${user}.home.activationPackage"; } (map (el: { name = el; }) hmFlavors)

      hashes = [
        { name = "fakeSha"; value = inputs.nixpkgs.lib.fakeSha256; }
        { name = "longSha"; value = longSha; }
        { name = "suggestedSha"; value = suggestedSha; }
      ];

      cases = inputs.nixpkgs.lib.cartesianProductOfSets {
        flavor = map (fl: fl.name) flavors;
        sha = map (h: h.value) hashes;
      };


      generateConfigs = listOf
    in
    rec {
      nixosConfigurations = {
        # use an override inside of the home manager module configuration
        hmOverrideWithFakeSha = nixosConfigurationConstructor {
          flavor = "hmOverride";
          sha = lib.fakeSha256;
        };
        hmOverrideWithLongSha = nixosConfigurationConstructor { flavor = "hmOverride"; sha = longSha; };
        hmOverrideWithSuggestedSha = nixosConfigurationConstructor { flavor = "hmOverrde"; sha = suggestedSha; };

        # use an overlay inside of the home manager module configuration
        hmOverlayWithFakeSha = nixosConfigurationConstructor { flavor = "hmOverride"; sha = lib.fakeSha256; };
        hmOverlayWithLongSha = nixosConfigurationConstructor { flavor = "hmOverride"; sha = longSha; };
        hmOverlayWithSuggestedSha = nixosConfigurationConstructor { flavor = "hmOverride"; sha = suggestedSha; };

        # use an override inside of the system configuration
        globalOverrideWithFakeSha = nixosConfigurationConstructor { flavor = "globalOverride"; sha = lib.fakeSha256; };
        globalOverrideWithLongSha = nixosConfigurationConstructor { flavor = "globalOverride"; sha = longSha; };
        globalOverrideWithSuggestedSha = nixosConfigurationConstructor { flavor = "globalOverride"; sha = suggestedSha; };

        # use an overlay inside of the system configuration
        globalOverlayWithFakeSha = nixosConfigurationConstructor { flavor = "globalOverlay"; sha = lib.fakeSha256; };
        globalOverlayWithLongSha = nixosConfigurationConstructor { flavor = "globalOverlay"; sha = longSha; };
        globalOverlayWithSuggestedSha = nixosConfigurationConstructor { flavor = "globalOverlay"; sha = suggestedSha; };

        # the nothing version
        unflavored = nixosConfigurationConstructor { flavor = ""; sha = ""; };
      };

      packages.x86_64-linux = {
        dbeaverHmOverrideWithFakeSha = nixosConfigurations.hmOverrideWithFakeSha.config.home-manager.users.john.home.activationPackage;
        dbeaverHmOverrideWithLongSha = nixosConfigurations.hmOverrideWithLongSha.config.home-manager.users.john.home.activationPackage;
        dbeaverHmOverrideWithSuggestedSha = nixosConfigurations.hmOverrideWithSuggestedSha.config.home-manager.users.john.home.activationPackage;

        dbeaverHmOverlayWithFakeSha = nixosConfigurations.hmOverlayWithFakeSha.config.home-manager.users.john.home.activationPackage;
        dbeaverHmOverlayWithLongSha = nixosConfigurations.hmOverlayWithLongSha.config.home-manager.users.john.home.activationPackage;
        dbeaverHmOverlayWithSuggestedSha = nixosConfigurations.hmOverlayWithSuggestedSha.config.home-manager.users.john.home.activationPackage;

        dbeaverSystemOverrideWithFakeSha = nixosConfigurations.globalOverrideWithFakeSha.pkgs.dbeaver;
        dbeaverSystemOverrideWithLongSha = nixosConfigurations.globalOverrideWithLongSha.pkgs.dbeaver;
        dbeaverSystemOverrideWithSuggestedSha = nixosConfigurations.globalOverrideWithSuggestedSha.pkgs.dbeaver;

        dbeaverSystemOverlayWithFakeSha = nixosConfigurations.globalOverlayWithFakeSha.pkgs.dbeaver;
        dbeaverSystemOverlayWithLongSha = nixosConfigurations.globalOverlayWithLongSha.pkgs.dbeaver;
        dbeaverSystemOverlayWithSuggestedSha = nixosConfigurations.globalOverlayWithSuggestedSha.pkgs.dbeaver;

        dbeaverSystemUnflavored = nixosConfigurations.unflavored.pkgs.dbeaver;
        dbeaverHmUnflavored = nixosConfigurations.unflavored.config.home-manager.users.john.home.activationPackage;
      };
    };

}
