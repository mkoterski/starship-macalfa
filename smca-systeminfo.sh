#!/bin/zsh
# smca-systeminfo.sh
# starship-macalfa — system snapshot for bug reports
#
# Captures hardware, GPU, macOS version, Homebrew deps, and Starship build
# info into a single text file. Called automatically by smca-collect-crash.sh.
#
# Usage:
#   ./smca-systeminfo.sh                  # write to logs/
#   ./smca-systeminfo.sh --out /some/dir  # write to specified directory
#   ./smca-systeminfo.sh --print          # also print to stdout
#
# CHANGELOG
# v0.10 (2026-03-30) - Initial version; ported from sysinfo.sh v0.11
#                      with pdmv conventions; starship.cfg.json parsing;
#                      top-level logs/

set -eo pipefail
VERSION="0.10"
SCRIPT_DIR="${0:A:h}"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"
PRINT_STDOUT=0

REPO_DIR="$SCRIPT_DIR/Starship"
BUILD_DIR="$REPO_DIR/build-cmake"

# ── Parse arguments ───────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)   OUT_DIR="$2";   shift 2 ;;
    --print) PRINT_STDOUT=1; shift ;;
    *) echo "Usage: $0 [--out <dir>] [--print]" >&2; exit 1 ;;
  esac
done

OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/logs}"
mkdir -p "$OUT_DIR"
OUTFILE="$OUT_DIR/sysinfo-$TIMESTAMP.txt"

w() {
  echo "$@" >> "$OUTFILE"
  (( PRINT_STDOUT )) && echo "$@" || true
}

# ── Header ────────────────────────────────────────────────────────────────────

w "════════════════════════════════════════════════════════════════"
w " Starship SF64 macalfa — System Snapshot"
w " smca-systeminfo.sh v$VERSION — $(date)"
w "════════════════════════════════════════════════════════════════"
w ""

# ── macOS & Hardware ──────────────────────────────────────────────────────────

w "── macOS ────────────────────────────────────────────────────────"
sw_vers >> "$OUTFILE" 2>&1
w "Kernel: $(uname -r)"
w "Architecture: $(uname -m)"
w ""

w "── Hardware ─────────────────────────────────────────────────────"
system_profiler SPHardwareDataType 2>/dev/null \
  | grep -E 'Model Name|Model Identifier|Processor|Cores|Memory|Serial' \
  | sed 's/^[[:space:]]*/  /' >> "$OUTFILE"
w ""

# ── GPU & OpenGL ──────────────────────────────────────────────────────────────

w "── GPU / Metal ──────────────────────────────────────────────────"
system_profiler SPDisplaysDataType 2>/dev/null \
  | grep -E 'Chipset|VRAM|Metal|Vendor|Device|Resolution|Pixel' \
  | sed 's/^[[:space:]]*/  /' >> "$OUTFILE"
w ""

w "── OpenGL ───────────────────────────────────────────────────────"
system_profiler SPDisplaysDataType 2>/dev/null \
  | grep -iE 'OpenGL|GLSL' \
  | sed 's/^[[:space:]]*/  /' >> "$OUTFILE" || true
w "  Note: GL renderer string requires active context (launch game to capture)"
BINARY="$BUILD_DIR/Starship"
w "  Linked: $(otool -L "$BINARY" 2>/dev/null | grep -i opengl | xargs || echo 'n/a')"
w ""

# ── Homebrew dependencies ─────────────────────────────────────────────────────

w "── Homebrew dependencies ────────────────────────────────────────"
if command -v brew &>/dev/null; then
  for pkg in sdl2 glew cmake ninja libpng zlib; do
    VER="$(brew list --versions "$pkg" 2>/dev/null || echo 'not installed')"
    w "  $pkg: $VER"
  done
else
  w "  brew not found"
fi
w ""

# ── Starship binary ───────────────────────────────────────────────────────────

w "── Starship binary ──────────────────────────────────────────────"
if [[ -f "$BINARY" ]]; then
  w "  Path:   $BINARY"
  w "  Size:   $(du -h "$BINARY" | cut -f1)"
  w "  Arch:   $(file "$BINARY" | cut -d: -f2 | xargs)"
  w "  Built:  $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$BINARY")"
  w "  Linked libs (otool -L):"
  otool -L "$BINARY" 2>/dev/null | sed 's/^/    /' >> "$OUTFILE" || true
else
  w "  Binary not found at $BINARY"
  w "  Run: ./smca-build-macos.sh"
fi
w ""

# ── starship.cfg.json ─────────────────────────────────────────────────────────

w "── starship.cfg.json ────────────────────────────────────────────"
CFG="$BUILD_DIR/starship.cfg.json"
if [[ -f "$CFG" ]]; then
  python3 - "$CFG" >> "$OUTFILE" 2>&1 << 'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f:
        cfg = json.load(f)
    win     = cfg.get("Window", {})
    backend = win.get("Backend", {})
    bid     = backend.get("Id",   "?")
    bname   = backend.get("Name", "?")
    audio   = win.get("AudioBackend", "?")
    print(f"  Backend:      {bid} ({bname})")
    print(f"  AudioBackend: {audio}")
    cvars = cfg.get("CVars", {})
    for key in ["gRenderer.InternalResolution", "gAspectRatioX", "gAspectRatioY",
                "gFullscreen", "gNotifications"]:
        val = cvars.get(key, {})
        if isinstance(val, dict):
            val = val.get("value", "?")
        if val != "?":
            print(f"  {key}: {val}")
except Exception as e:
    print(f"  Error reading config: {e}")
PYEOF
else
  w "  starship.cfg.json not found at $CFG"
fi
w ""

# ── Disk & Memory ─────────────────────────────────────────────────────────────

w "── Disk & Memory ────────────────────────────────────────────────"
w "  Disk (project): $(du -sh "$SCRIPT_DIR" 2>/dev/null | cut -f1)"
w "  Disk (build):   $(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1)"
df -h "$SCRIPT_DIR" 2>/dev/null | tail -1 \
  | awk '{print "  Free on volume: " $4}' >> "$OUTFILE"
vm_stat 2>/dev/null \
  | grep -E 'Pages (free|active|wired)' \
  | awk '{printf "  vm_stat: %s\n", $0}' >> "$OUTFILE" || true
w ""

# ── Footer ────────────────────────────────────────────────────────────────────

w "════════════════════════════════════════════════════════════════"
w " End of snapshot — $(date)"
w "════════════════════════════════════════════════════════════════"

echo "✅ smca-systeminfo.sh v$VERSION → $OUTFILE"