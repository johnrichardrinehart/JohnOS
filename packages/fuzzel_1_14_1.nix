{ fuzzel, fetchurl }:

fuzzel.overrideAttrs (_old: rec {
  version = "1.14.1";
  src = fetchurl {
    url = "https://codeberg.org/dnkl/fuzzel/archive/${version}.tar.gz";
    hash = "sha256-xkFnhsOgYAuK2R7ZUcQ8ACpjmHDDgjtKYMkQRC9K4Jc=";
  };
})
