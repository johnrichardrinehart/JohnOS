#!/usr/bin/env bash
set -euo pipefail

watch_mode=0
interval=30

while [ "$#" -gt 0 ]; do
  case "$1" in
    --watch)
      watch_mode=1
      ;;
    --interval)
      shift
      interval="$1"
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: codex-weekly-pace [--watch] [--interval SECONDS]" >&2
      exit 2
      ;;
  esac
  shift
done

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "codex-weekly-pace: missing required command: $1" >&2
    exit 127
  fi
}

for cmd in jq rg awk sed date; do
  require_tool "$cmd"
done

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_RESET=$'\033[0m'
else
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
  C_RESET=""
fi

if printf '\u2014' >/dev/null 2>&1; then
  UNDER_MARKER="——"
else
  UNDER_MARKER="--"
fi

find_latest_snapshot_json() {
  local today_dir line
  today_dir="$HOME/.codex/sessions/$(date +%Y/%m/%d)"

  if [ -d "$today_dir" ]; then
    line="$(rg -n '"type":"token_count".*"limit_id":"codex"' -S "$today_dir" --glob '*.jsonl' | tail -n 1 || true)"
  else
    line=""
  fi

  if [ -z "$line" ]; then
    line="$(rg -n '"type":"token_count".*"limit_id":"codex"' -S "$HOME/.codex/sessions" --glob '*.jsonl' | tail -n 1 || true)"
  fi

  if [ -z "$line" ]; then
    return 1
  fi

  printf '%s\n' "$line" | sed -E 's/^[^:]+:[0-9]+://'
}

format_minutes() {
  local mins d h m
  mins="$1"
  if [ "$mins" -lt 60 ]; then
    printf "%dm" "$mins"
    return
  fi

  if [ "$mins" -lt 1440 ]; then
    h=$((mins / 60))
    m=$((mins % 60))
    printf "%02dh %02dm" "$h" "$m"
    return
  fi

  d=$((mins / 1440))
  h=$(((mins % 1440) / 60))
  m=$((mins % 60))
  printf "%dd %02dh %02dm" "$d" "$h" "$m"
}

one_shot() {
  local snapshot
  snapshot="$(find_latest_snapshot_json)" || {
    echo "No Codex token_count snapshot found under ~/.codex/sessions"
    return 1
  }

  local used win_min reset now start elapsed remain expected gap expected_h
  used="$(printf '%s\n' "$snapshot" | jq -r '.payload.rate_limits.secondary.used_percent')"
  win_min="$(printf '%s\n' "$snapshot" | jq -r '.payload.rate_limits.secondary.window_minutes')"
  reset="$(printf '%s\n' "$snapshot" | jq -r '.payload.rate_limits.secondary.resets_at')"
  now="$(date +%s)"

  start=$((reset - win_min * 60))
  elapsed=$((now - start))
  remain=$((reset - now))

  if [ "$elapsed" -lt 0 ]; then
    elapsed=0
  fi
  if [ "$remain" -lt 0 ]; then
    remain=0
  fi

  expected="$(awk -v e="$elapsed" -v w="$win_min" 'BEGIN { if (w <= 0) print 0; else print (e / (w * 60.0)) * 100.0 }')"
  gap="$(awk -v u="$used" -v x="$expected" 'BEGIN { print u - x }')"
  expected_h="$(awk 'BEGIN { print 100.0 / 168.0 }')"

  local sign magnitude
  sign="$(awk -v g="$gap" -v u="$UNDER_MARKER" 'BEGIN { if (g > 0.000001) print "+"; else if (g < -0.000001) print u; else print "="; }')"
  magnitude="$(awk -v g="$gap" 'BEGIN { if (g < 0) g = -g; print g }')"

  printf "weekly %s%.2f%% (used %.2f%% vs expected %.2f%%) | reset in %s\n" \
    "$sign" "$magnitude" \
    "$used" "$expected" "$(format_minutes $(((remain + 59) / 60)))"

  local rates rate drift eta_h eta_min remain_min label
  rates="0.1 0.25 0.5"
  remain_min=$(((remain + 59) / 60))

  for rate in $rates; do
    label="$(printf '%s%%/h' "$rate")"
    drift="$(awk -v r="$rate" -v e="$expected_h" 'BEGIN { print r - e }')"

    if awk -v g="$gap" 'BEGIN { exit !(g > 0.000001) }'; then
      if awk -v d="$drift" 'BEGIN { exit !(d < -0.000001) }'; then
        eta_h="$(awk -v g="$gap" -v d="$drift" 'BEGIN { print g / (-d) }')"
      else
        eta_h=""
      fi
    elif awk -v g="$gap" 'BEGIN { exit !(g < -0.000001) }'; then
      if awk -v d="$drift" 'BEGIN { exit !(d > 0.000001) }'; then
        eta_h="$(awk -v g="$gap" -v d="$drift" 'BEGIN { print (-g) / d }')"
      else
        eta_h=""
      fi
    else
      eta_h="0"
    fi

    if [ -z "$eta_h" ]; then
      printf "  %s: %snever%s\n" "$label" "$C_RED" "$C_RESET"
      continue
    fi

    eta_min="$(awk -v h="$eta_h" 'BEGIN { m = int(h * 60.0); if (h * 60.0 > m) m = m + 1; print m }')"
    if [ "$eta_min" -gt "$remain_min" ]; then
      printf "  %s: %sno catch-up before reset%s (need %s)\n" "$label" "$C_RED" "$C_RESET" "$(format_minutes "$eta_min")"
    else
      color=""
      if [ "$eta_min" -ge 480 ]; then
        color="$C_RED"
      elif [ "$eta_min" -ge 60 ]; then
        color="$C_YELLOW"
      else
        color="$C_GREEN"
      fi

      printf "  %s: %s%s%s\n" "$label" "$color" "$(format_minutes "$eta_min")" "$C_RESET"
    fi
  done
}

if [ "$watch_mode" -eq 1 ]; then
  while true; do
    printf '\033[2J\033[H'
    printf 'codex-weekly-pace  (%s)\n\n' "$(date +'%Y-%m-%d %H:%M:%S %z')"
    one_shot || true
    sleep "$interval"
  done
else
  one_shot
fi
