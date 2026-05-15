{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=1bf77d8fad6721ca33f72eb5b3984c3183747474")
.packages.${system}.repo-manager
