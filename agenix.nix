args @ { config, pkgs, ... }:
{
  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    args.agenix.defaultPackage.x86_64-linux
  ];

  age.sshKeyPaths = [ "/home/john/.ssh/id_rsa" "/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets.secret1 = {
    file = ./secrets/secret1.age;
    owner = "john";
  };
}
