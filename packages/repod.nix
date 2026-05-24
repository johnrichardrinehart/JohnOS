{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=2929e164a370050560cb29e4d470fecd74c74dbf")
.packages.${system}.repod
