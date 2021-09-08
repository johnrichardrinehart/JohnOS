args @ { pkgs, lib, config, nixpkgs, options, specialArgs, nixosConfig, ... }:
let
  extraPackages = let p = pkgs; in
    [
      p.teams
      p.awscli
      p.ssm-session-manager-plugin
      p.postman
      p.go
      p.python39
      p.python39Packages.pylint
    ];

  programs = {
    git = {
      userEmail = "john.rinehart@ardanlabs.com";
    };
  };

  zshInitExtra =
    ''
      function ssm-stable-instance-id {
          aws ec2 describe-instances --filter "Name=tag:Name,Values=LinuxBastion" "Name=tag:Environment,Values=Stable" "Name=tag:Business Unit,Values=BNET" --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[] | [0]" --output text
      }

      function ssm-stable-bastion {
          aws --profile=stable-bastion ssm start-session --target $(ssm-stable-instance-id)
      }

      alias stable-bastion-id="aws --profile stable-bastion ec2 describe-instances --filter \"Name=tag:Name,Values=LinuxBastion\" \"Name=tag:Environment,Values=Stable\" \"Name=tag:Business Unit,Values=BNET\" --query \"Reservations[].Instances[?State.Name == 'running'].InstanceId[] | [0]\" --output text"

      function stable-bastion {
          aws --profile stable-bastion ssm start-session --target $(stable-bastion-id)
      }

      function stable-bastion-key {
          aws --profile stable-bastion secretsmanager get-secret-value --secret-id 'arn:aws:secretsmanager:us-east-1:410935837022:secret:/bethesdanet/infra/ssh/services-managed-internal' --query 'SecretString' --output text > ~/.ssh/bnet-stable-bastion.pem && chmod 0600 ~/.ssh/*.pem
      }

      alias prod-bastion-id="aws --profile prod-bastion ec2 describe-instances --filter \"Name=tag:Name,Values=LinuxBastion\" \"Name=tag:Environment,Values=Prod\" \"Name=tag:Business Unit,Values=BNET\" --query \"Reservations[].Instances[?State.Name == 'running'].InstanceId[] | [0]\" --output text"

      function prod-bastion {
          aws --profile prod-bastion ssm start-session --target $(prod-bastion-id)
      }

      function prod-bastion-key {
          aws --profile prod-bastion secretsmanager get-secret-value --secret-id 'arn:aws:secretsmanager:us-east-1:455286985801:secret:/bethesdanet/infra/ssh/services-managed-external' --query 'SecretString' --output text > ~/.ssh/bnet-prod-bastion.pem && chmod 0600 ~/.ssh/*.pem
      }

      export PATH=$PATH:$HOME/go/bin
    '';
in
(import ./common.nix) (args // { inherit extraPackages zshInitExtra programs; })
