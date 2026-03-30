# Custom packages for JohnOS
{ pkgs, rock5cPkgs }:

{
  agent-deck = pkgs.callPackage ./agent-deck.nix { };
  codex-cli-nix = pkgs.callPackage ./codex-cli-nix.nix { };
  omx-agent-tools = pkgs.callPackage ./omx-agent-tools.nix { };
  oh-my-codex = pkgs.callPackage ./oh-my-codex.nix { };
  libcrossguid-with-pc = rock5cPkgs."libcrossguid-with-pc";
  libcrossguid_with_pc = rock5cPkgs.libcrossguid_with_pc;
  ffmpeg_8-v4l2request = rock5cPkgs."ffmpeg_8-v4l2request";
  ffmpeg_8-full-v4l2request = rock5cPkgs."ffmpeg_8-full-v4l2request";
  ffmpeg_8-rkmpp = rock5cPkgs."ffmpeg_8-rkmpp";
  ffmpeg_8-full-rkmpp = rock5cPkgs."ffmpeg_8-full-rkmpp";
  ffmpeg_8-rkmpp-v4l2request = rock5cPkgs."ffmpeg_8-rkmpp-v4l2request";
  ffmpeg_8-full-rkmpp-v4l2request = rock5cPkgs."ffmpeg_8-full-rkmpp-v4l2request";
  ffmpeg_8-rockchip = rock5cPkgs."ffmpeg_8-rockchip";
  ffmpeg_8-full-rockchip = rock5cPkgs."ffmpeg_8-full-rockchip";
  ffmpeg_8-rockchip-v4l2request = rock5cPkgs."ffmpeg_8-rockchip-v4l2request";
  ffmpeg_8-full-rockchip-v4l2request = rock5cPkgs."ffmpeg_8-full-rockchip-v4l2request";
  rockchip_mpp = rock5cPkgs.rockchip_mpp;
  mpv_v4l2request = rock5cPkgs.mpv_v4l2request;
  mpv_rockchip = rock5cPkgs.mpv_rockchip;
}
