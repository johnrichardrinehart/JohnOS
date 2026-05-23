{
  inputs = {
    nixpkgs.url = "github:johnrichardrinehart/nixpkgs?ref=rock-5c-nixos-25.11";

    flake-parts.url = "github:hercules-ci/flake-parts";

    flake-templates.url = "github:NixOS/templates/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      flake = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rock5c-nixos = {
      url = "github:johnrichardrinehart/rock5c-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.flake-parts.flakeModules.partitions ];

      systems = [ "x86_64-linux" ];

      partitionedAttrs = {
        checks = "dev";
        devShells = "dev";
        formatter = "dev";
      };

      partitions.dev = {
        extraInputsFlake = ./dev;
        module =
          { inputs, ... }:
          {
            perSystem =
              { system, ... }:
              let
                overlays = import ./overlays inputs;
                pkgs = import inputs.nixpkgs {
                  inherit system;
                  overlays = [ overlays.default ];
                };
                treefmtEval = inputs."treefmt-nix".lib.evalModule pkgs ./treefmt.nix;
                preCommitCheck = inputs."git-hooks".lib.${system}.run {
                  src = ./.;
                  hooks = {
                    treefmt-nix = {
                      enable = true;
                      name = "treefmt";
                      entry = "${treefmtEval.config.build.wrapper}/bin/treefmt --fail-on-change";
                      language = "system";
                      pass_filenames = false;
                    };
                  };
                };
              in
              {
                devShells = import ./dev-shells.nix {
                  inherit pkgs;
                  inherit preCommitCheck;
                  treefmtBin = treefmtEval.config.build.wrapper;
                };

                checks = {
                  pre-commit = preCommitCheck;
                  formatting = treefmtEval.config.build.check inputs.self;
                };

                formatter = treefmtEval.config.build.wrapper;
              };
          };
      };

      flake = {
        nixosConfigurations = import ./nixos-configurations inputs;

        nixosModules.default = import ./nixos-modules {
          inherit inputs;
          inherit (inputs.nixpkgs) lib;
        };

        overlays = import ./overlays inputs;
      };

      perSystem =
        { system, ... }:
        let
          overlays = import ./overlays inputs;
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ overlays.default ];
          };
        in
        {
          packages = import ./packages { inherit pkgs; };
        };
    };
}
