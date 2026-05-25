{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=a217d8eb7e768e8f2f2e96cdc94b60ce0b8c6796")
.packages.${system}.repo-manager
