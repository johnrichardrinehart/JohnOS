{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=d2526807a81b5c39f16081c3859fa679e6223e15")
.packages.${system}.repo-manager
