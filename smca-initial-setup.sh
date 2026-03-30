#!/bin/zsh
# smca-initial-setup.sh
# starship-macalfa — first-run setup for macOS Tahoe / Intel Mac
#
# Installs Xcode CLT, Homebrew, and build dependencies.
# Validates the ROM if already present in the central roms/ directory.
# Safe to re-run: all steps are idempotent.
#
# Usage:
#   ./smca-initial-setup.sh
#
# Output:
#   logs/initial-setup-<timestamp>.log
#
# ROM layout (place file here before building):
#   roms/baserom.us.rev1.z64   US Rev 1 (SHA1: 09F0D105F...)
#
# CHANGELOG
# v0.10 (2026-03-30) - Initial version; ported from pdmv-initial-setup.sh v0.13
#                      and starship-macalfa pre-restructure build deps

set -eo pipefail
VERSION="0.10"
SCRIPT_DIR="${0:A:h}"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"
LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/initial-setup-$TIMESTAMP.log"

mkdir -p "$LOG_DIR"
echo "🛠 smca-initial-setup.sh v$VERSION — $(date)" | tee -a "$LOGFILE"
echo "   macOS: $(sw_vers -productName) $(sw_vers -productVersion)" | tee -a "$LOGFILE"
echo "   Arch:  $(uname -m)" | tee -a "$LOGFILE"

# ── Architecture guard ────────────────────────────────────────────────────────

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "⚠️  Non-Intel architecture detected ($(uname -m))." | tee -a "$LOGFILE"
  echo "   This project targets Intel x86_64 Macs." | tee -a "$LOGFILE"
  echo "   On Apple Silicon, use Rosetta 2 or build a native arm64 variant." | tee -a "$LOGFILE"
fi

# ── Step 1: Xcode Command Line Tools ─────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔧 Step 1: Xcode Command Line Tools" | tee -a "$LOGFILE"
if ! xcode-select -p &>/dev/null; then
  echo "   Not found — launching installer." | tee -a "$LOGFILE"
  echo "   Complete the GUI prompt, then re-run this script." | tee -a "$LOGFILE"
  xcode-select --install
  exit 0
fi
echo "   ✅ $(xcode-select -p)" | tee -a "$LOGFILE"

# ── Step 2: Homebrew ──────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🍺 Step 2: Homebrew" | tee -a "$LOGFILE"
if ! command -v brew &>/dev/null; then
  echo "   Installing Homebrew..." | tee -a "$LOGFILE"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1 | tee -a "$LOGFILE"
  eval "$(/usr/local/bin/brew shellenv)"
fi
echo "   ✅ $(brew --version | head -1)" | tee -a "$LOGFILE"

# ── Step 3: Homebrew packages ─────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📦 Step 3: Homebrew packages" | tee -a "$LOGFILE"
for pkg in cmake ninja sdl2 glew libpng zlib git; do
  if ! brew list --versions "$pkg" &>/dev/null; then
    echo "   Installing $pkg..." | tee -a "$LOGFILE"
    brew install "$pkg" 2>&1 | tee -a "$LOGFILE"
  else
    echo "   ✅ $(brew list --versions "$pkg")" | tee -a "$LOGFILE"
  fi
done

# ── Step 4: ROM status ────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🎮 Step 4: ROM status" | tee -a "$LOGFILE"
echo "   Checking roms/ directory: $SCRIPT_DIR/roms/" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

ROM_PATH="$SCRIPT_DIR/roms/baserom.us.rev1.z64"
ROM_SHA1="09F0D105F476B00EFA5303A3EBC42E60A7753B7A"

if [[ -f "$ROM_PATH" ]]; then
  ACTUAL="$(shasum -a 1 "$ROM_PATH" | awk '{print toupper($1)}')"
  if [[ "$ACTUAL" == "$ROM_SHA1" ]]; then
    echo "   ✅ baserom.us.rev1.z64 — $(du -h "$ROM_PATH" | cut -f1)  SHA1 OK" | tee -a "$LOGFILE"
  else
    echo "   ⚠️  baserom.us.rev1.z64 — SHA1 MISMATCH" | tee -a "$LOGFILE"
    echo "       got:      $ACTUAL" | tee -a "$LOGFILE"
    echo "       expected: $ROM_SHA1" | tee -a "$LOGFILE"
  fi
else
  echo "   · baserom.us.rev1.z64 — not present → roms/baserom.us.rev1.z64" | tee -a "$LOGFILE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"
echo "✅ smca-initial-setup.sh v$VERSION complete!" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"
echo "   Next steps:" | tee -a "$LOGFILE"
echo "   1. Place ROM in roms/  (see path above)" | tee -a "$LOGFILE"
echo "   2. ./smca-build-macos.sh           # build from source" | tee -a "$LOGFILE"
echo "   3. ./run-smca-macos.sh             # launch (OpenGL)" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"