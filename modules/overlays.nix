[
#  (self: super: {
#    waybar = super.waybar.overrideAttrs (oldAttrs: {
#      mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
#    });
#  })
  (self: super: {
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
