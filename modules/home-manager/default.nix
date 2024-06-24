{ ... }: {
  imports = [
    ./dwm
    ./i3
    ./xmonad
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
