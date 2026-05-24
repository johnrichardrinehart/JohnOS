{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=d2d613cd43e6f8a175057e6f2d0278ecd656daa6")
.packages.${system}.repod
