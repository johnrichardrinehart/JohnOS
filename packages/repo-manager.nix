{ system }:

(builtins.getFlake "github:johnrichardrinehart/repo-manager/d6f975a072fa918d9e3771476e942ce259f1cbd3")
.packages.${system}.repo-manager
