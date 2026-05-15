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

exec "$PYTHON" "$ROOT/p4v.py" "$@"
