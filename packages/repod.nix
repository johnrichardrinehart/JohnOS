{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=0f647205b455d795ef075136dee98320cb61037a")
.packages.${system}.repod
