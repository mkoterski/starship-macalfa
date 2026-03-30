#!/bin/zsh
# run-smca-macos.sh
# starship-macalfa — Intel Mac / macOS Tahoe launcher
#
# Usage:
#   ./run-smca-macos.sh                    # launch with OpenGL (Intel Mac default)
#   ./run-smca-macos.sh --opengl           # force OpenGL for this session
#   ./run-smca-macos.sh --metal            # force Metal for this session
#   ./run-smca-macos.sh --metal --debug    # Metal + MTL_DEBUG_LAYER=1
#   ./run-smca-macos.sh --debug            # current backend + MTL_DEBUG_LAYER=1
#   ./run-smca-macos.sh --restore-cfg      # restore latest config backup and exit
#
# Backend handling:
#   Default on Intel Mac is OpenGL — Metal crashes with bad_variant_access in
#   the prism shader compiler on Tahoe 26.3. --metal is available for testing.
#   Backend changes are session-only: starship.cfg.json is backed up before
#   launch and restored on clean exit or SIGINT/SIGTERM via trap.
#
# Log output:
#   logs/run-<timestamp>.log    ← top-level logs/, last 5 runs kept
#   logs/starship.cfg.backup-<timestamp>.json
#
# CHANGELOG
# v0.10 (2026-03-30) - Initial version; ported from run-starship.sh v1.10
#                      with pdmv conventions; all features preserved:
#                      backend switching, config backup/restore, gamecontrollerdb
#                      auto-download, o2r asset checks, Torch auto-generate,
#                      DYLD paths, log rotation

set -eo pipefail
VERSION="0.10"
SCRIPT_DIR="${0:A:h}"
LOG_KEEP=5

REPO_DIR="$SCRIPT_DIR/Starship"
BUILD_DIR="$REPO_DIR/build-cmake"
BINARY="$BUILD_DIR/Starship"
CFG="$BUILD_DIR/starship.cfg.json"
TORCH="$BUILD_DIR/TorchExternal/src/TorchExternal-build/torch"
ROM_FILE="$REPO_DIR/baserom.z64"
GAMEDB="$BUILD_DIR/gamecontrollerdb.txt"
GAMEDB_URL="https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/master/gamecontrollerdb.txt"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"

LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/run-$TIMESTAMP.log"
CFG_BACKUP="$LOG_DIR/starship.cfg.backup-$TIMESTAMP.json"

mkdir -p "$LOG_DIR"

# ── Parse arguments ───────────────────────────────────────────────────────────

BACKEND="opengl"
DEBUG_LAYER=0
RESTORE_CFG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --opengl)      BACKEND="opengl"; shift ;;
    --metal)       BACKEND="metal";  shift ;;
    --debug)       DEBUG_LAYER=1;    shift ;;
    --restore-cfg) RESTORE_CFG=1;    shift ;;
    *) echo "Usage: $0 [--opengl|--metal] [--debug] [--restore-cfg]" >&2; exit 1 ;;
  esac
done

# ── Restore mode ──────────────────────────────────────────────────────────────

if (( RESTORE_CFG )); then
  LATEST_BAK="$(ls -t "$LOG_DIR"/starship.cfg.backup-*.json 2>/dev/null | head -1 || true)"
  if [[ -n "$LATEST_BAK" ]]; then
    cp "$LATEST_BAK" "$CFG"
    echo "✅ Restored: $CFG"
    echo "   From: $LATEST_BAK"
  else
    echo "⚠️  No starship.cfg.json backup found in $LOG_DIR/" >&2; exit 1
  fi
  exit 0
fi

echo "🎮 run-smca-macos.sh v$VERSION — $(date)" | tee -a "$LOGFILE"
echo "   Backend: $BACKEND (Intel Mac — OpenGL recommended)" | tee -a "$LOGFILE"
echo "   Log:     $LOGFILE" | tee -a "$LOGFILE"

# ── Config backup + trap restore ──────────────────────────────────────────────

CFG_MODIFIED=0

_restore_cfg() {
  if (( CFG_MODIFIED )) && [[ -f "$CFG_BACKUP" ]]; then
    cp "$CFG_BACKUP" "$CFG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Config restored from backup" | tee -a "$LOGFILE"
  fi
}
trap _restore_cfg EXIT INT TERM

if [[ -f "$CFG" ]]; then
  cp "$CFG" "$CFG_BACKUP"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Config backup → ${CFG_BACKUP##$SCRIPT_DIR/}" | tee -a "$LOGFILE"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [warn] starship.cfg.json not found — will be created on first launch" | tee -a "$LOGFILE"
fi

# ── Backend override (session-only) ───────────────────────────────────────────

if [[ "$BACKEND" = "opengl" ]]; then BID=1; BNAME="OpenGL"
else                                  BID=2; BNAME="Metal";  fi

if [[ -f "$CFG" ]]; then
  python3 - "$CFG" "$BID" "$BNAME" << 'PYEOF'
import json, sys
path, bid, bname = sys.argv[1], int(sys.argv[2]), sys.argv[3]
with open(path) as f:
    cfg = json.load(f)
cfg.setdefault("Window", {})["Backend"] = {"Id": bid, "Name": bname}
with open(path, "w") as f:
    json.dump(cfg, f, indent=4)
PYEOF
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Backend: $BNAME (Id $BID) — session only, restored on exit" | tee -a "$LOGFILE"
  CFG_MODIFIED=1
fi

# ── Metal debug layer ─────────────────────────────────────────────────────────

if (( DEBUG_LAYER )); then
  export MTL_DEBUG_LAYER=1
  export MTL_DEBUG_LAYER_ERROR=crash
  echo "$(date '+%Y-%m-%d %H:%M:%S') [warn] MTL_DEBUG_LAYER=1 enabled — Metal validation active (slow)" | tee -a "$LOGFILE"
fi

# ── DYLD library paths ────────────────────────────────────────────────────────

export DYLD_LIBRARY_PATH="/usr/local/opt/sdl2/lib:/usr/local/opt/glew/lib:/usr/local/opt/libvorbis/lib:/usr/local/opt/libogg/lib:${DYLD_LIBRARY_PATH:-}"

# ── Preflight checks ──────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Preflight checks..." | tee -a "$LOGFILE"

if [[ ! -f "$BINARY" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [error] Binary not found: $BINARY" | tee -a "$LOGFILE"
  echo "   Run: ./smca-build-macos.sh" | tee -a "$LOGFILE"
  exit 1
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Binary: $(du -h "$BINARY" | cut -f1)" | tee -a "$LOGFILE"

# ── gamecontrollerdb.txt ──────────────────────────────────────────────────────

if [[ ! -s "$GAMEDB" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Downloading gamecontrollerdb.txt..." | tee -a "$LOGFILE"
  if curl -fsSL "$GAMEDB_URL" -o "$GAMEDB" 2>&1 | tee -a "$LOGFILE"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [info] gamecontrollerdb.txt downloaded ($(wc -l < "$GAMEDB") entries)" | tee -a "$LOGFILE"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [warn] Download failed — creating empty placeholder" | tee -a "$LOGFILE"
    touch "$GAMEDB"
  fi
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] gamecontrollerdb.txt present ($(wc -l < "$GAMEDB") entries)" | tee -a "$LOGFILE"
fi

# ── sf64.o2r ──────────────────────────────────────────────────────────────────

if [[ ! -f "$BUILD_DIR/sf64.o2r" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Generating sf64.o2r (ExtractAssets)..." | tee -a "$LOGFILE"
  cmake --build "$BUILD_DIR" --target ExtractAssets 2>&1 | tee -a "$LOGFILE" || \
    echo "$(date '+%Y-%m-%d %H:%M:%S') [warn] ExtractAssets failed — run ./smca-build-macos.sh" | tee -a "$LOGFILE"
fi

# ── starship.o2r ──────────────────────────────────────────────────────────────

if [[ ! -f "$BUILD_DIR/starship.o2r" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Generating starship.o2r (GeneratePortO2R)..." | tee -a "$LOGFILE"
  cmake --build "$BUILD_DIR" --target GeneratePortO2R 2>&1 | tee -a "$LOGFILE" || \
    echo "$(date '+%Y-%m-%d %H:%M:%S') [warn] GeneratePortO2R failed — run ./smca-build-macos.sh" | tee -a "$LOGFILE"
fi

# ── Asset integrity check ─────────────────────────────────────────────────────

echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Assets:" | tee -a "$LOGFILE"
ls -lh "$BUILD_DIR"/*.o2r 2>&1 | tee -a "$LOGFILE"
if [[ ! -f "$BUILD_DIR/sf64.o2r" ]] || [[ ! -f "$BUILD_DIR/starship.o2r" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [error] Missing required .o2r assets — aborting!" | tee -a "$LOGFILE"
  exit 1
fi

# ── Launch ────────────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Launching Starship ($BNAME)..." | tee -a "$LOGFILE"
cd "$BUILD_DIR"
./Starship 2>&1 | tee -a "$LOGFILE"
EXIT_CODE=${pipestatus[1]}

echo "" | tee -a "$LOGFILE"
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Starship exited cleanly (code 0)" | tee -a "$LOGFILE"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [warn] Starship exited with code $EXIT_CODE" | tee -a "$LOGFILE"
fi

# ── Log rotation ──────────────────────────────────────────────────────────────

RUN_LOGS=("${(@f)$(ls -t "$LOG_DIR"/run-*.log 2>/dev/null)}")
if (( ${#RUN_LOGS[@]} > LOG_KEEP )); then
  TO_DELETE=("${RUN_LOGS[@]:$LOG_KEEP}")
  for old in "${TO_DELETE[@]}"; do
    rm -f "$old"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Log rotated: ${old:t}" | tee -a "$LOGFILE"
  done
fi

echo "" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"
echo "✅ run-smca-macos.sh v$VERSION complete!" | tee -a "$LOGFILE"
echo "   📄 $LOGFILE" | tee -a "$LOGFILE"
echo "   💾 Keeping last $LOG_KEEP run logs" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"