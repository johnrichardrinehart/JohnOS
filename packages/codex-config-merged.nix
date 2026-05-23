{
  jq,
  lib,
  name,
  remarshal,
  runCommand,
  layers,
  header,
}:

runCommand name
  {
    nativeBuildInputs = [
      jq
      remarshal
    ];
  }
  ''
    i=0
    json_inputs=()

    for layer in ${lib.escapeShellArgs layers}; do
      i=$((i + 1))
      remarshal -if toml -of json "$layer" > "$TMPDIR/layer-$i.json"
      json_inputs+=("$TMPDIR/layer-$i.json")
    done

    jq -s '
      def merge(a; b):
        reduce (b | keys_unsorted[]) as $k
          (a; .[$k] = if ((a[$k] | type) == "object" and (b[$k] | type) == "object")
                       then merge(a[$k]; b[$k])
                       else b[$k]
                       end);

      reduce .[] as $item ({}; merge(.; $item))
      | .features = ((.features // {}) + { hooks: true })
      | .features |= del(.codex_hooks)
    ' "''${json_inputs[@]}" > "$TMPDIR/config.merged.json"

    remarshal -if json -of toml "$TMPDIR/config.merged.json" > "$TMPDIR/config.merged.toml"
    cat ${header} "$TMPDIR/config.merged.toml" > "$out"
  ''
