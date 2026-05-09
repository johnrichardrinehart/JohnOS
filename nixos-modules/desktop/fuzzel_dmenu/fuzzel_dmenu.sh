#!/bin/sh

window_list=$(niri msg --json windows)
entries=$(printf '%s\n' "$window_list" | jq -r 'map(select(.is_focused | not)) | .[] | "[\(.app_id)(\(.id))]: \(.title)"')
[ -n "$entries" ] || exit 0

width=$(printf '%s\n' "$entries" | wc -L | tr -d ' ')
width=$((width + 2))
[ "$width" -lt 40 ] && width=40
[ "$width" -gt 90 ] && width=90

name=$(printf '%s\n' "$entries" | fuzzel --dmenu --width "$width") || exit 0
id=$(printf '%s\n' "$window_list" | jq -r --arg name "$name" '.[] | select("[\(.app_id)(\(.id))]: \(.title)" == $name) | .id' | head -n 1)
[ -n "$id" ] || exit 0

niri msg action focus-window --id "$id"
