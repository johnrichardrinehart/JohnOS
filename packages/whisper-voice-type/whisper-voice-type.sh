#!/usr/bin/env bash
set -euo pipefail

export PYTHONPATH="${DICTATION_LIB:?}:${PYTHONPATH:-}"
export MOONSHINE_MODEL_PATH="${MOONSHINE_MODEL_PATH:?}"
export MOONSHINE_MODEL_ARCH="${MOONSHINE_MODEL_ARCH:?}"
export NOTIFY_SEND="${NOTIFY_SEND:?}"
export PACTL="${PACTL:?}"
export WPCTL="${WPCTL:?}"
export WTYPE="${WTYPE:?}"
export SETSID="${SETSID:?}"
export DAEMON_SCRIPT="${DAEMON_SCRIPT:?}"
export TRAIN_SCRIPT="${TRAIN_SCRIPT:?}"
export REVIEW_SCRIPT="${REVIEW_SCRIPT:?}"
exec "${PYTHON:?}" "${CLI_SCRIPT:?}" "$@"
