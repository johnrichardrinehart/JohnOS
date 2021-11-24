{ users ? {
    dummy = {
      password = "password";
    };
  }
}:
{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  users.extraUsers = users;
}
