inputs: {
  default =
    final: prev:
    let
      inherit (inputs.nixpkgs) lib;
      packageRoot = ../packages;
      packageEntries = builtins.readDir packageRoot;
      packageFiles = lib.filterAttrs (
        name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
      ) packageEntries;
      packageDirs = lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (packageRoot + "/${name}/default.nix")
      ) packageEntries;
      packagePaths =
        lib.mapAttrs' (
          name: _: lib.nameValuePair (lib.removeSuffix ".nix" name) (packageRoot + "/${name}")
        ) packageFiles
        // lib.mapAttrs (name: _: packageRoot + "/${name}") packageDirs;
      kdlfmt_0_1_7 = prev.kdlfmt.overrideAttrs (_old: {
        version = "0.1.7";
        src = final.fetchFromGitHub {
          owner = "hougesen";
          repo = "kdlfmt";
          tag = "v0.1.7";
          hash = "sha256-Ftzf4gI7E5tPo8U5ZxUMqlY5+AK5IEUUAll+GsEKYpg=";
        };
        cargoHash = "sha256-B/ir+Sf4uxQ9Fqmy6yEa3DMt0qdpfPrwD8lhUMOEUbo=";
      });
      packageArgs = {
        clipboard-watch.clipboard-store-notify = johnPkgs.clipboard-store-notify;
        codex-config-merged = {
          name = "codex-config-merged.toml";
          layers = [ ];
          header = final.writeText "codex-config-merged-empty-header.toml" "";
        };
        codex-omx-layer.oh-my-codex = johnPkgs.oh-my-codex;
        confirm-ssh-activity-before-suspend.promptTimeoutSeconds = 15 * 60;
        droidcam-v4l2loopback.kernel = final.linuxPackages_latest.kernel;
        framework-ec-flash = {
          inherit (johnPkgs) framework-ec;
          frameworkTool = final.framework-tool;
        };
        fuzzel-dmenu = {
          fuzzel = johnPkgs.fuzzel_1_14_1;
          inherit (johnPkgs) niri;
        };
        fuzzel_1_14_1.fuzzel = prev.fuzzel;
        kdlfmt.kdlfmt = kdlfmt_0_1_7;
        kill-idle-group.onIdlePackage = johnPkgs.on-idle;
        libmoonshine.onnxruntime = johnPkgs.onnxruntime-openvino;
        lock-idle-ssh-sessions = {
          idleTimeoutSeconds = 5 * 60;
          terminalMultiplexer = "tmux";
          inherit (johnPkgs) tmux;
        };
        moonshine-models-onnx = {
          inherit (final) python3;
          modelDir = johnPkgs.moonshine-models-source;
        };
        moonshine-voice = {
          inherit (johnPkgs) libmoonshine;
          onnxruntime = johnPkgs.onnxruntime-openvino;
        };
        niri-cycle-display-mode = {
          fuzzel = johnPkgs.fuzzel_1_14_1;
          inherit (johnPkgs) niri;
        };
        niri-gather-windows.niri = johnPkgs.niri;
        niri-screenshot = {
          inherit (johnPkgs) niri;
          inherit (johnPkgs) wormhole-send;
        };
        omx-agent-tools = {
          inherit (johnPkgs) codex-cli-nix;
          inherit (johnPkgs) oh-my-codex;
        };
        on-idle.idleTimeoutSeconds = 5 * 60;
        repo-manager.system = final.stdenv.hostPlatform.system;
        repod.system = final.stdenv.hostPlatform.system;
        whisper-voice-type = {
          moonshineVoice = johnPkgs.moonshine-voice;
          model = johnPkgs.moonshine-models-onnx;
        };
        tmux = {
          inherit (prev) fetchpatch2 tmux;
        };
        util-linux.util-linux = prev.util-linux;
      };
      johnPkgs = lib.mapAttrs (
        name: path: final.callPackage path (packageArgs.${name} or { })
      ) packagePaths;
    in
    {
      dev = (prev.dev or { }) // {
        johnrinehart = johnPkgs;
      };
    };
}
