#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ODP_DIR="$ROOT/odpdom"
SRC_DIR="$ROOT/src"
LIB_DIR="$ROOT/lib"
PYTHON="${PYTHON:-python3}"
CXX="${CXX:-g++}"
SWIG="${SWIG:-swig}"
PYTHON_CONFIG="${PYTHON_CONFIG:-python3-config}"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Required command '$1' was not found in PATH." >&2
        exit 1
    fi
}

python_value() {
    "$PYTHON" - "$@" <<'PY'
import importlib.machinery
import sys
import sysconfig

key = sys.argv[1]
if key == "include":
    print(sysconfig.get_path("include"))
elif key == "ext_suffix":
    print(importlib.machinery.EXTENSION_SUFFIXES[0])
else:
    raise SystemExit(f"unknown query: {key}")
PY
}

find_fltk_config() {
    if [[ -n "${FLTK_CONFIG:-}" ]]; then
        echo "$FLTK_CONFIG"
        return
    fi
    if command -v fltk-config >/dev/null 2>&1; then
        command -v fltk-config
        return
    fi
    if command -v fltk1.3-config >/dev/null 2>&1; then
        command -v fltk1.3-config
        return
    fi
    echo "fltk-config was not found. Install libfltk1.3-dev first." >&2
    exit 1
}

split_flags() {
    local -n out_ref=$1
    local value=$2
    # fltk-config/python-config output shell-style flags without embedded whitespace.
    read -r -a out_ref <<< "$value"
}

compile_sources() {
    local directory=$1
    shift
    local -n sources_ref=$1
    shift
    local -n flags_ref=$1

    pushd "$directory" >/dev/null
    for source in "${sources_ref[@]}"; do
        local object="${source%.*}.o"
        echo "Compiling $(basename "$directory")/$source"
        "$CXX" "${flags_ref[@]}" -c "$source" -o "$object"
    done
    popd >/dev/null
}

require_command "$PYTHON"
require_command "$CXX"
require_command "$SWIG"
require_command "$PYTHON_CONFIG"

FLTK_CONFIG_BIN="$(find_fltk_config)"
PY_INCLUDE="$(python_value include)"
EXT_SUFFIX="$(python_value ext_suffix)"
PY_LDFLAGS_VALUE="$("$PYTHON_CONFIG" --embed --ldflags 2>/dev/null || "$PYTHON_CONFIG" --ldflags)"
FLTK_CXXFLAGS_VALUE="$("$FLTK_CONFIG_BIN" --use-gl --cxxflags)"
FLTK_LDFLAGS_VALUE="$("$FLTK_CONFIG_BIN" --use-gl --ldflags)"

split_flags PY_LDFLAGS "$PY_LDFLAGS_VALUE"
split_flags FLTK_CXXFLAGS "$FLTK_CXXFLAGS_VALUE"
split_flags FLTK_LDFLAGS "$FLTK_LDFLAGS_VALUE"

mkdir -p "$LIB_DIR"

PY_DOM_DEFINE='-DPY_DOMEXC_MODULE="p4vasp.ODPdom."'
COMMON_DEFINES=("$PY_DOM_DEFINE" -DCHECK=1 -DVERBOSE=0 -DNO_GL_LISTS_S -DNO_THREADS)

echo "Using Python include: $PY_INCLUDE"
echo "Using extension suffix: $EXT_SUFFIX"
echo "Using FLTK config: $FLTK_CONFIG_BIN"

pushd "$ODP_DIR" >/dev/null
echo "Generating odpdom/cODP_wrap.cpp"
"$SWIG" -python -c++ "$PY_DOM_DEFINE" -Iinclude -o cODP_wrap.cpp ODP.i
popd >/dev/null

ODP_SOURCES=(
    string.cpp
    markText.cpp
    Exceptions.cpp
    Node.cpp
    NodeSequences.cpp
    Document.cpp
    CharacterNodes.cpp
    Element.cpp
    parse.cpp
)
ODP_FLAGS=(-std=gnu++11 -fPIC -w "$PY_DOM_DEFINE" "-I$PY_INCLUDE" -Iinclude)
compile_sources "$ODP_DIR" ODP_SOURCES ODP_FLAGS

if [[ ! -f "$SRC_DIR/cp4vasp_wrap.cpp" ]]; then
    pushd "$SRC_DIR" >/dev/null
    echo "Generating src/cp4vasp_wrap.cpp"
    "$SWIG" -python -c++ -Wall "${COMMON_DEFINES[@]}" \
        -I../odpdom/include -Iinclude -o cp4vasp_wrap.cpp cp4vasp.i
    popd >/dev/null
fi

P4VASP_SOURCES=(
    Exceptions.cpp
    AtomtypesRecord.cpp
    AtomInfo.cpp
    vecutils3d.cpp
    vecutils.cpp
    utils.cpp
    domutils.cpp
    FArray.cpp
    Structure.cpp
    Chgcar.cpp
    ChgcarSmear.cpp
    Process.cpp
    VisFLWindow.cpp
    VisMain.cpp
    VisWindow.cpp
    VisEvent.cpp
    VisDrawer.cpp
    VisNavDrawer.cpp
    VisStructureDrawer.cpp
    VisStructureArrowsDrawer.cpp
    VisIsosurfaceDrawer.cpp
    ClassInterface.cpp
    VisSlideDrawer.cpp
    VisPrimitiveDrawer.cpp
    VisBackEvent.cpp
    cp4vasp_wrap.cpp
)
P4VASP_FLAGS=(
    -std=gnu++11
    -fPIC
    -w
    "$PY_DOM_DEFINE"
    -DCHECK=1
    -DVERBOSE=0
    -DNO_GL_LISTS_S
    -DNO_THREADS
    -D_LARGEFILE_SOURCE
    -D_LARGEFILE64_SOURCE
    -D_FILE_OFFSET_BITS=64
    "-I$PY_INCLUDE"
    -Iinclude
    -I../odpdom/include
    "${FLTK_CXXFLAGS[@]}"
)
compile_sources "$SRC_DIR" P4VASP_SOURCES P4VASP_FLAGS

P4VASP_OBJECTS=()
for source in "${P4VASP_SOURCES[@]}"; do
    P4VASP_OBJECTS+=("$SRC_DIR/${source%.*}.o")
done

ODP_OBJECTS=()
for source in "${ODP_SOURCES[@]}"; do
    ODP_OBJECTS+=("$ODP_DIR/${source%.*}.o")
done

OUTPUT="$LIB_DIR/_cp4vasp$EXT_SUFFIX"
rm -f "$LIB_DIR"/_cp4vasp*.so

echo "Linking $OUTPUT"
"$CXX" -shared -o "$OUTPUT" \
    "${P4VASP_OBJECTS[@]}" \
    "${ODP_OBJECTS[@]}" \
    "${FLTK_LDFLAGS[@]}" \
    "${PY_LDFLAGS[@]}"

cp "$SRC_DIR/cp4vasp.py" "$LIB_DIR/cp4vasp.py"

echo "Checking Python imports"
PYTHONPATH="$LIB_DIR${PYTHONPATH:+:$PYTHONPATH}" P4VASP_HOME="$ROOT" \
    "$PYTHON" - <<'PY'
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
import _cp4vasp
import p4vasp
print("p4vasp Ubuntu build OK")
PY

echo "Built $OUTPUT"
