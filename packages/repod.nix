{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=1dcfdf6d4d3bc82fab75afedcdae624126b11383")
.packages.${system}.repod
