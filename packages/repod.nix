{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=fef320dc91de1c885813d0dd36ec11d9a81d010e")
.packages.${system}.repod
