{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=97909a8ff2f8236bc775b814c40d8e6aa0c36546")
.packages.${system}.repo-manager
