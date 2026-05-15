#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export P4VASP_HOME="$ROOT"
export PYTHONPATH="$ROOT/lib${PYTHONPATH:+:$PYTHONPATH}"
export UBUNTU_MENUPROXY="${UBUNTU_MENUPROXY:-0}"

exec "${PYTHON:-python3}" "$ROOT/p4v.py" "$@"
