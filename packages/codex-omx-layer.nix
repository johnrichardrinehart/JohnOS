{
  lib,
  oh-my-codex,
  runCommand,
}:

runCommand "codex-omx-layer"
  {
    outputs = [
      "out"
      "config"
      "hooks"
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    export CODEX_HOME="$HOME/.codex"

    mkdir -p "$HOME" "$TMPDIR/work"
    cd "$TMPDIR/work"

    ${lib.getExe oh-my-codex} setup --scope user --force --verbose > "$TMPDIR/setup.log"
    ${lib.getExe oh-my-codex} doctor > "$TMPDIR/doctor.log"

    if ! grep -Fq "[OK] Native hooks: hooks.json includes OMX-managed coverage for all native hook events" "$TMPDIR/doctor.log"; then
      cat "$TMPDIR/doctor.log" >&2
      exit 1
    fi

    cp "$CODEX_HOME/config.toml" "$config"
    cp "$CODEX_HOME/hooks.json" "$hooks"
    printf '%s\n' "config: $config" "hooks: $hooks" > "$out"
  ''
