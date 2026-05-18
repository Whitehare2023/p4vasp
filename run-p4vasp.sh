#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${PYTHON:-}" ]]; then
    if [[ -x "$ROOT/.venv-macos/bin/python3" ]]; then
        PYTHON="$ROOT/.venv-macos/bin/python3"
    elif [[ -x /usr/bin/python3 ]]; then
        PYTHON=/usr/bin/python3
    else
        PYTHON=python3
    fi
fi

export P4VASP_HOME="$ROOT"
export PYTHONPATH="$ROOT/lib${PYTHONPATH:+:$PYTHONPATH}"
export UBUNTU_MENUPROXY="${UBUNTU_MENUPROXY:-0}"

"$PYTHON" "$ROOT/p4v.py" "$@" &
child_pid=$!

cleanup() {
    if [[ -n "${child_pid:-}" ]] && kill -0 "$child_pid" 2>/dev/null; then
        kill -TERM "$child_pid" 2>/dev/null || true
    fi
}

trap 'cleanup; wait "$child_pid" 2>/dev/null || true; exit 130' INT
trap 'cleanup; wait "$child_pid" 2>/dev/null || true; exit 143' TERM
trap cleanup EXIT

set +e
wait "$child_pid"
status=$?
set -e

trap - INT TERM EXIT
exit "$status"
