#!/bin/sh

window_list=$(niri msg --json windows)
input_file=$(mktemp)
labels_file=$(mktemp)
desktop_index_file=$(mktemp)
trap 'rm -f "$input_file" "$labels_file" "$desktop_index_file"' EXIT

build_desktop_index() {
  data_dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/run/current-system/sw/share:/etc/profiles/per-user/${USER:-john}/share"

  old_ifs=$IFS
  IFS=:
  set --
  for data_dir in $data_dirs; do
    applications_dir=$data_dir/applications
    [ -d "$applications_dir" ] || continue
    for desktop_file in "$applications_dir"/*.desktop; do
      [ -f "$desktop_file" ] || continue
      set -- "$@" "$desktop_file"
    done
  done
  IFS=$old_ifs

  [ "$#" -gt 0 ] || return 0

  awk -F= '
    function emit(key) {
      key = tolower(key)
      if (key != "" && !(key in seen)) {
        printf "%s\t%s\t%s\n", key, icon, name
        seen[key] = 1
      }
    }

    FNR == 1 {
      in_desktop_entry = 0
      desktop_id = FILENAME
      sub(/^.*\//, "", desktop_id)
      sub(/\.desktop$/, "", desktop_id)
      icon = desktop_id
      name = desktop_id
      startup_wm_class = ""
    }

    $0 == "[Desktop Entry]" { in_desktop_entry = 1; next }
    /^\[/ { in_desktop_entry = 0; next }

    in_desktop_entry {
      value = $0
      sub(/^[^=]*=/, "", value)

      if ($1 == "Icon" && value != "") {
        icon = value
      } else if ($1 == "Name" && value != "") {
        name = value
      } else if ($1 == "StartupWMClass" && value != "") {
        startup_wm_class = value
      }
    }

    ENDFILE {
      emit(desktop_id)
      emit(startup_wm_class)
    }
  ' "$@" >"$desktop_index_file"
}

wait_for_layer_shell_namespace_to_close() {
  namespace=$1
  attempts=25

  while [ "$attempts" -gt 0 ]; do
    if niri msg --json layers | jq -e --arg namespace "$namespace" 'all(.[]; .namespace != $namespace)' >/dev/null; then
      return 0
    fi

    attempts=$((attempts - 1))
    sleep 0.01
  done
}

build_desktop_index

printf '%s\n' "$window_list" | jq -r 'map(select(.is_focused | not)) | .[] | [.id, .app_id, .title] | @tsv' |
  awk -F '	' -v desktop_index_file="$desktop_index_file" -v input_file="$input_file" -v labels_file="$labels_file" '
    BEGIN {
      while ((getline line < desktop_index_file) > 0) {
        split(line, fields, "\t")
        icons[fields[1]] = fields[2]
        names[fields[1]] = fields[3]
      }
      close(desktop_index_file)
    }

    {
      id = $1
      app_id = $2
      title = $3
      app_id_lower = tolower(app_id)
      icon = icons[app_id_lower]
      app_name = names[app_id_lower]

      if (icon == "") {
        icon = app_id
      }
      if (app_name == "") {
        app_name = app_id
      }

      if (title != "" && title != app_name) {
        label = app_name ": " title
      } else {
        label = app_name
      }

      print label >> labels_file
      printf "%s\t%s%cicon%c%s\n", id, label, 0, 31, icon >> input_file
    }
  '

[ -s "$labels_file" ] || exit 0

width=$(wc -L <"$labels_file" | tr -d ' ')
width=$((width + 2))
[ "$width" -lt 40 ] && width=40
[ "$width" -gt 90 ] && width=90

tab=$(printf '\t')
namespace="fuzzel-dmenu-window-picker-$$"
id=$(
  fuzzel --dmenu --namespace="$namespace" --with-nth=2 --accept-nth=1 --nth-delimiter="$tab" --width "$width" <"$input_file"
) || exit 0
[ -n "$id" ] || exit 0

# Avoid the fuzzel-close/niri-focus race that can leave the chosen floating window unfocused.
wait_for_layer_shell_namespace_to_close "$namespace"
niri msg action focus-window --id "$id"
