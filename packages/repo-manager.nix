{ system }:

(builtins.getFlake "github:johnrichardrinehart/repo-manager/b49b593a24b2b09c4a1390ffd9796e6cffd26961")
.packages.${system}.repo-manager
