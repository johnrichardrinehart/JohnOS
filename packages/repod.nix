{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=0a17d16fa553a1c1718ec774705e4a25a833be35")
.packages.${system}.repod
