{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.john = ../home-manager/users/john.nix;
    users.ardan = ../home-manager/users/ardan.nix;
  };
}
