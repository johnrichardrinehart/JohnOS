{
  lib,
  symlinkJoin,
  writeShellApplication,
  codex-cli-nix,
  oh-my-codex,
}:
let
  mkOmxWrapper =
    name: fixedArgs:
    writeShellApplication {
      inherit name;
      runtimeInputs = [
        codex-cli-nix
        oh-my-codex
      ];
      text = ''
        set -euo pipefail

        export OMX_CODEX_BIN="${lib.getExe codex-cli-nix}"

        fixed_args=(${lib.concatMapStringsSep " " lib.escapeShellArg fixedArgs})

        passthrough=()
        resume_id=""
        saw_resume=0

        while [ "$#" -gt 0 ]; do
          case "$1" in
            resume)
              saw_resume=1
              shift
              if [ "$#" -eq 0 ]; then
                echo "${name}: missing session id after resume" >&2
                exit 2
              fi
              resume_id="$1"
              shift
              while [ "$#" -gt 0 ]; do
                passthrough+=("$1")
                shift
              done
              ;;
            *)
              passthrough+=("$1")
              shift
              ;;
          esac
        done

        if [ "$saw_resume" -eq 1 ]; then
          exec ${lib.getExe oh-my-codex} resume "$resume_id" "''${fixed_args[@]}" "''${passthrough[@]}"
        fi

        exec ${lib.getExe oh-my-codex} "''${fixed_args[@]}" "''${passthrough[@]}"
      '';
    };

  omxHigh = mkOmxWrapper "omx-high" [ "--high" ];
  omxHighSandboxedRalph = mkOmxWrapper "omx-high-sandboxed-ralph" [
    "--ask-for-approval"
    "never"
    "--sandbox"
    "workspace-write"
    "--high"
  ];
in
symlinkJoin {
  name = "omx-agent-tools";
  paths = [
    omxHigh
    omxHighSandboxedRalph
  ];

  meta = with lib; {
    description = "Agent-deck-friendly OMX wrapper commands";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
