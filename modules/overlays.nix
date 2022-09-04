[
  (self: super: {
    vscodium = super.vscodium.overrideAttrs (final: prev:
    (let
      plat = "linux-x64";
      archive_fmt = "tar.gz";
      versions = {
        "1.69.2" = "sha256-xpNqBVB1iD/NQtaW7nHZ5GBvC8nJxA27FOhfnr2ydU8=";
        "1.70.0" = "sha256-AclhcuFd0ajAiALpJyYRGQ7PA2IS2luOVtMZot3plm8=";
        "local" = "";
      };
    version = "1.69.2";
    sha256 = versions.${version};
    in
      {
        src = if version == "local" then
        "/home/john/code/repos/others/microsoft/vscode"
        else super.fetchurl {
        url =  "https://github.com/VSCodium/vscodium/releases/download/${version}/VSCodium-${plat}-${version}.${archive_fmt}";
        inherit sha256;
      }; 
      inherit version;
    }));
  })
]
