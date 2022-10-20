[
  (self: super: {
    vscodium = super.vscodium.overrideAttrs (final: prev:
      (
        let
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
          src =
            if version == "local" then
              "/home/john/code/repos/others/microsoft/vscode"
            else
              super.fetchurl {
                url = "https://github.com/VSCodium/vscodium/releases/download/${version}/VSCodium-${plat}-${version}.${archive_fmt}";
                inherit sha256;
              };
          inherit version;
        }
      ));

    python310Packages = super.python310Packages // ({
      poetry = super.python310Packages.poetry.overrideAttrs (final: prev:
        {
          src = super.fetchFromGitHub {
            owner = "python-poetry";
            repo = "poetry";
            rev = "77003f157c72dad63c2a2fe2f5a974b16818aaca";
            sha256 = "sha256-nVRN5N6mPUjB/ilyq70zFADN2ibdJGgOqfqUWWSW8Ko=";
          };
          version = "77003f157c72dad63c2a2fe2f5a974b16818aaca";
          patches = [ ];
        });
    });

    kubectl = super.kubectl.overrideAttrs (final: prev:
      {
        version = "1.25.0";
      });

    #  google-cloud-sdk = super.google-cloud-sdk.overrideAttrs (final: prev: {
    #    components = super.google-cloud-sdk.withExtraComponents [ super.google-cloud-sdk.components.gke-gcloud-auth-plugin ];
    #  });
    #
  })
]
