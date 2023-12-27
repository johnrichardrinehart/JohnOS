let
  minikube-beta =
    let
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      lib = pkgs.lib;
      version = "v1.26.0-beta.1";
      src = pkgs.fetchFromGitHub {
        owner = "kubernetes";
        rev = "${version}";
        repo = "minikube";
        sha256 = "sha256-oafO/K7+oXxp/SyvjcKdXZ+mOUVrrgcVuFmCyoNPbaw=";
      };
      name = "minikube-${version}";
    in
    (pkgs.callPackage "${pkgs.path}/pkgs/applications/networking/cluster/minikube" {
      vmnet = pkgs.darwin.apple_sdk.framworks.vmnet;
      buildGoModule = args: pkgs.buildGoModule (args // {
        inherit name src version;
        vendorSha256 = "sha256-JtNlvTSnlPuhr0nsBkH6Ke+Y6fCFyBAlduSPcMS8SS4=";
      });
    });
in
[
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
    inherit minikube-beta;
  })
]
