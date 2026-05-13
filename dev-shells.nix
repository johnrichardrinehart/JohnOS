{
  pkgs,
  preCommitCheck,
  treefmtBin,
}:

{
  default = pkgs.mkShell {
    buildInputs =
      (with pkgs; [
        nix
        nixos-rebuild
        git
      ])
      ++ preCommitCheck.enabledPackages;

    shellHook = ''
      ${preCommitCheck.shellHook}
      export TREEFMT_BIN=${treefmtBin}
      echo "JohnOS development environment"
    '';
  };
}
