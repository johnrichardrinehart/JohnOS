{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=b412656403017734f66004821ce2d0a91b6895cf")
.packages.${system}.repo-manager
