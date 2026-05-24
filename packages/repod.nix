{ system }:

(builtins.getFlake "git+https://github.com/johnrichardrinehart/repo-manager?rev=aae4c4342d7672253769b0f13af4c163b504265d")
.packages.${system}.repod
