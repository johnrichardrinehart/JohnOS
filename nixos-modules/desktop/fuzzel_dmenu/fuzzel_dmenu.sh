#!/bin/sh

set -x
window_list=$(niri msg --json windows)
name=$(echo $window_list | jq -r 'map(select(.is_focused | not)) | .[] | "[\(.app_id)(\(.id))]: \(.title)"' | fuzzel --dmenu --width 120)
id=$(echo $window_list | jq -r '.[] | "[\(.app_id)(\(.id))]: \(.title)", "\(.id)"' | grep -F "$name" -x -A 1 | grep -F "$name" -vx)

niri msg action focus-window --id $id
