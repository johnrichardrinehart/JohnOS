{ system }:

(builtins.getFlake "github:johnrichardrinehart/repo-manager/9f35813dab3e9969b0e35f73776cb20abb7f8c38")
.packages.${system}.repo-manager
