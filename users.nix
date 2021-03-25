{
  users ? {
     dummy = {
        password = "password";
     };
   }
}:
{config, pkgs, ...}:
{
  users.extraUsers = users;
}
