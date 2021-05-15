let
  user1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0idNvgGiucWgup/mP78zyC23uFjYq0evcWdjGQUaBH";
in
{
  secret1 = {
    age = {
      publicKeys = [ user1 ];
    };
  };
}
