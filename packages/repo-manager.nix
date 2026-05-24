{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=fb2e2af83507e1a2753ebcf3b633e4992dcacad9")
.packages.${system}.repo-manager
