#!/bin/zsh
# smca-patch-hidpi.sh
# starship-macalfa — Retina HiDPI patch for SDL window + viewport
#
# Finds the SDL_CreateWindow call in the upstream source tree and adds
# SDL_WINDOW_ALLOW_HIGHDPI so macOS reports physical pixel dimensions.
# Also patches SDL_GL_GetDrawableSize into the viewport size query.
#
# Usage:
#   ./smca-patch-hidpi.sh --check    # scan source tree (no changes)
#   ./smca-patch-hidpi.sh --apply    # apply patch to source files
#   ./smca-patch-hidpi.sh --revert   # restore .bak originals
#
# CHANGELOG
# v0.10 (2026-03-30) - Initial version; ported from patch-hidpi.sh v0.10
#                      with pdmv conventions; search paths now inside
#                      Starship/ clone directory

set -eo pipefail
VERSION="0.10"
SCRIPT_DIR="${0:A:h}"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"
REPO_DIR="$SCRIPT_DIR/Starship"
BUILD_DIR="$REPO_DIR/build-cmake"

LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/patch-hidpi-$TIMESTAMP.log"
mkdir -p "$LOG_DIR"

# ── Parse arguments ───────────────────────────────────────────────────────────

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)  MODE="check";  shift ;;
    --apply)  MODE="apply";  shift ;;
    --revert) MODE="revert"; shift ;;
    *) echo "Usage: $0 --check | --apply | --revert" >&2; exit 1 ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 --check | --apply | --revert" >&2
  exit 1
fi

echo "🖥️  smca-patch-hidpi.sh v$VERSION — $(date)" | tee -a "$LOGFILE"
echo "   Mode: $MODE" | tee -a "$LOGFILE"
echo "   Source: $REPO_DIR" | tee -a "$LOGFILE"

if [[ ! -d "$REPO_DIR/src" ]]; then
  echo "❌ Upstream source not found — run ./smca-build-macos.sh first" | tee -a "$LOGFILE"
  exit 1
fi

# ── Revert mode ───────────────────────────────────────────────────────────────

if [[ "$MODE" = "revert" ]]; then
  echo "" | tee -a "$LOGFILE"
  echo "↩️  Reverting HiDPI patches..." | tee -a "$LOGFILE"
  REVERTED=0
  for bak in $REPO_DIR/src/**/*.bak(N) $REPO_DIR/libultraship/**/*.bak(N); do
    ORIG="${bak%.bak}"
    mv "$bak" "$ORIG"
    echo "   ✅ Restored: ${ORIG##$REPO_DIR/}" | tee -a "$LOGFILE"
    (( REVERTED++ ))
  done
  if (( REVERTED == 0 )); then
    echo "   ℹ️  No .bak files found — nothing to revert" | tee -a "$LOGFILE"
  else
    echo "" | tee -a "$LOGFILE"
    echo "✅ Reverted $REVERTED file(s). Run ./smca-build-macos.sh to rebuild." | tee -a "$LOGFILE"
  fi
  exit 0
fi

# ── Scan source tree ──────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔍 Scanning source tree..." | tee -a "$LOGFILE"

SEARCH_DIRS=("$REPO_DIR/src" "$REPO_DIR/libultraship" "$REPO_DIR/extern")
EXTS=("*.cpp" "*.h" "*.mm" "*.c")

# ── Find SDL_CreateWindow ─────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "── SDL_CreateWindow ─────────────────────────────────────────────" | tee -a "$LOGFILE"
CREATEWINDOW_FILES=()
for dir in "${SEARCH_DIRS[@]}"; do
  [[ -d "$dir" ]] || continue
  for ext in "${EXTS[@]}"; do
    while IFS= read -r line; do
      echo "   $line" | tee -a "$LOGFILE"
      CREATEWINDOW_FILES+=("${line%%:*}")
    done < <(grep -rn "SDL_CreateWindow" "$dir" --include="$ext" 2>/dev/null || true)
  done
done
if (( ${#CREATEWINDOW_FILES[@]} == 0 )); then
  echo "   ℹ️  SDL_CreateWindow not found in src/ or libultraship/" | tee -a "$LOGFILE"
fi

# ── Find existing SDL_WINDOW_ flags ──────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "── SDL_WINDOW_ flags ────────────────────────────────────────────" | tee -a "$LOGFILE"
for dir in "${SEARCH_DIRS[@]}"; do
  [[ -d "$dir" ]] || continue
  for ext in "${EXTS[@]}"; do
    grep -rn "SDL_WINDOW_" "$dir" --include="$ext" 2>/dev/null \
      | grep -v "ALLOW_HIGHDPI" \
      | sed 's/^/   /' | tee -a "$LOGFILE" || true
  done
done

# ── Check if ALLOW_HIGHDPI already present ────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "── SDL_WINDOW_ALLOW_HIGHDPI (already patched?) ───────────────────" | tee -a "$LOGFILE"
ALREADY_PATCHED=0
for dir in "${SEARCH_DIRS[@]}"; do
  [[ -d "$dir" ]] || continue
  for ext in "${EXTS[@]}"; do
    HITS="$(grep -rn "SDL_WINDOW_ALLOW_HIGHDPI" "$dir" --include="$ext" 2>/dev/null || true)"
    if [[ -n "$HITS" ]]; then
      echo "$HITS" | sed 's/^/   ✅ /' | tee -a "$LOGFILE"
      ALREADY_PATCHED=1
    fi
  done
done
if (( ALREADY_PATCHED == 0 )); then
  echo "   ℹ️  SDL_WINDOW_ALLOW_HIGHDPI not found — patch needed" | tee -a "$LOGFILE"
fi

# ── Find glViewport / drawable size ───────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "── glViewport / drawable size ───────────────────────────────────" | tee -a "$LOGFILE"
for dir in "${SEARCH_DIRS[@]}"; do
  [[ -d "$dir" ]] || continue
  for ext in "${EXTS[@]}"; do
    grep -rn "glViewport\|GetDrawableSize\|GetWindowSize\|SDL_GetWindowSize" \
      "$dir" --include="$ext" 2>/dev/null \
      | sed 's/^/   /' | tee -a "$LOGFILE" || true
  done
done

# ── Check mode ────────────────────────────────────────────────────────────────

if [[ "$MODE" = "check" ]]; then
  echo "" | tee -a "$LOGFILE"
  echo "✅ smca-patch-hidpi.sh v$VERSION --check complete" | tee -a "$LOGFILE"
  echo "   📄 $LOGFILE" | tee -a "$LOGFILE"
  echo "   👉 Review output above, then run: ./smca-patch-hidpi.sh --apply" | tee -a "$LOGFILE"
  exit 0
fi

# ── Apply mode ────────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔧 Applying HiDPI patches..." | tee -a "$LOGFILE"

PATCHED=0
CREATEWINDOW_FILES=(${(u)CREATEWINDOW_FILES})

for f in "${CREATEWINDOW_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  if grep -q "SDL_WINDOW_" "$f" && ! grep -q "SDL_WINDOW_ALLOW_HIGHDPI" "$f"; then
    cp "$f" "${f}.bak"
    perl -i -pe '
      if (/SDL_WINDOW_/ && !/SDL_WINDOW_ALLOW_HIGHDPI/) {
        s/(SDL_WINDOW_(?!ALLOW_HIGHDPI)\w+)(\s*[|;,\)])/$1 | SDL_WINDOW_ALLOW_HIGHDPI$2/g
      }
    ' "$f"
    echo "   ✅ Patched: ${f##$REPO_DIR/}" | tee -a "$LOGFILE"
    echo "      Backup:  ${f##$REPO_DIR/}.bak" | tee -a "$LOGFILE"
    (( PATCHED++ ))
  elif grep -q "SDL_WINDOW_ALLOW_HIGHDPI" "$f"; then
    echo "   ℹ️  Already patched: ${f##$REPO_DIR/}" | tee -a "$LOGFILE"
  fi
done

if (( PATCHED == 0 )); then
  echo "" | tee -a "$LOGFILE"
  echo "   ⚠️  No files patched automatically." | tee -a "$LOGFILE"
  echo "      SDL_CreateWindow may be inside libultraship or SDL2 internals." | tee -a "$LOGFILE"
  echo "      Check the --check output and apply the flag manually." | tee -a "$LOGFILE"
else
  echo "" | tee -a "$LOGFILE"
  echo "   👉 Also check glViewport calls manually — replace SDL_GetWindowSize" | tee -a "$LOGFILE"
  echo "      with SDL_GL_GetDrawableSize to use physical pixel dimensions." | tee -a "$LOGFILE"
fi

echo "" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"
echo "✅ smca-patch-hidpi.sh v$VERSION --apply complete!" | tee -a "$LOGFILE"
echo "   📄 $LOGFILE" | tee -a "$LOGFILE"
echo "   👉 Run ./smca-build-macos.sh to rebuild, then ./run-smca-macos.sh" | tee -a "$LOGFILE"
echo "   👉 To undo: ./smca-patch-hidpi.sh --revert" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"