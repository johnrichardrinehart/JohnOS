{ fetchurl, buildLinux, ... }@args:

buildLinux (
  args
  // rec {
    version = "5.16.10";
    modDirVersion = "5.16.10";

    kernelPatches = [ ];

    src = fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
      sha256 = "sha256-DE1vAIGABZOFLrFVsB4Jt4tbxp16VT/Fj1rSBw+QI54=";
    };

  }
  // (args.argsOverride or { })
)
