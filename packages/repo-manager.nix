{ system }:

(builtins.getFlake "github:johnrichardrinehart/repo-manager/519afa3683266848faed7d2808e5d929e26a686a")
.packages.${system}.repo-manager
