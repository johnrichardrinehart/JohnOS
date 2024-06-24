{ ... }: {
  imports = [
    ({
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users = {
          john = ./common.nix;
        };
      };
    })
  ];
}
