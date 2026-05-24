{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=b7b4f9fbd306551e8b718a16781276ddb8e269f1")
.packages.${system}.repod
