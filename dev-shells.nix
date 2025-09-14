{ pkgs }:

{
  default = pkgs.mkShell {
    buildInputs = with pkgs; [
      nix
      nixos-rebuild
      git
    ];

    shellHook = ''
      echo "JohnOS development environment"
    '';
  };
}
