#!/bin/zsh
# smca-build-macos.sh
# starship-macalfa — Intel Mac / macOS Tahoe build script
#
# Checks and installs all prerequisites inline (Homebrew, packages),
# then clones or updates HarbourMasters/Starship, copies the ROM from
# the central roms/ directory, configures cmake with Ninja, and compiles
# the binary. Torch generates sf64.o2r from the ROM after build.
#
# Usage:
#   ./smca-build-macos.sh
#
# ROM layout (place file here — build script copies it automatically):
#   roms/baserom.us.rev1.z64   US Rev 1 (SHA1: 09F0D105F...)
#
# Log output:
#   logs/build-<timestamp>.log   ← top-level logs/, survives rm -rf Starship/
#
# CHANGELOG
# v0.10 (2026-03-30) - Initial version; ported from starship-macalfa v1.0
#                      fork build + pdmv-build-macos.sh v0.16 conventions;
#                      scripts-only repo: clones upstream at build time

set -eo pipefail
VERSION="0.10"
SCRIPT_DIR="${0:A:h}"

REPO_DIR="$SCRIPT_DIR/Starship"
BUILD_DIR="$REPO_DIR/build-cmake"
BINARY="$BUILD_DIR/Starship"
ROM_SOURCE="$SCRIPT_DIR/roms/baserom.us.rev1.z64"
ROM_FILE="$REPO_DIR/baserom.z64"
TORCH="$BUILD_DIR/TorchExternal/src/TorchExternal-build/torch"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"

LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/build-$TIMESTAMP.log"
mkdir -p "$LOG_DIR"

echo "🔨 smca-build-macos.sh v$VERSION — $(date)" | tee -a "$LOGFILE"
echo "   Log: $LOGFILE" | tee -a "$LOGFILE"

# ── Step 1: Homebrew ──────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🍺 Step 1: Homebrew" | tee -a "$LOGFILE"
if ! command -v brew &>/dev/null; then
  echo "   Installing Homebrew..." | tee -a "$LOGFILE"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1 | tee -a "$LOGFILE"
  eval "$(/usr/local/bin/brew shellenv)"
fi
echo "   ✅ $(brew --version | head -1)" | tee -a "$LOGFILE"

# ── Step 2: Homebrew packages ─────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📦 Step 2: Homebrew packages" | tee -a "$LOGFILE"
for pkg in cmake ninja sdl2 glew libpng zlib git; do
  if ! brew list --versions "$pkg" &>/dev/null; then
    echo "   Installing $pkg..." | tee -a "$LOGFILE"
    brew install "$pkg" 2>&1 | tee -a "$LOGFILE"
  else
    echo "   ✅ $(brew list --versions "$pkg")" | tee -a "$LOGFILE"
  fi
done

# ── Step 3: Xcode CLT ─────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔧 Step 3: Xcode CLT" | tee -a "$LOGFILE"
if ! xcode-select -p &>/dev/null; then
  echo "   ❌ Xcode Command Line Tools not found." | tee -a "$LOGFILE"
  echo "      Run: xcode-select --install  then re-run this script." | tee -a "$LOGFILE"
  exit 1
fi
echo "   ✅ $(xcode-select -p)" | tee -a "$LOGFILE"

# ── Step 4: Clone or update ───────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📥 Step 4: Clone / update HarbourMasters/Starship" | tee -a "$LOGFILE"
if [[ ! -f "$REPO_DIR/CMakeLists.txt" ]]; then
  [[ -d "$REPO_DIR" ]] && echo "   ⚠️  Repo dir exists but CMakeLists.txt missing — removing and re-cloning..." | tee -a "$LOGFILE"
  rm -rf "$REPO_DIR"
  echo "   Cloning..." | tee -a "$LOGFILE"
  git clone --recursive https://github.com/HarbourMasters/Starship.git "$REPO_DIR" 2>&1 | tee -a "$LOGFILE"
else
  echo "   Repo exists — pulling latest..." | tee -a "$LOGFILE"
  git -C "$REPO_DIR" pull --recurse-submodules 2>&1 | tee -a "$LOGFILE"
fi

# ── Step 5: ROM ───────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🎮 Step 5: ROM" | tee -a "$LOGFILE"
if [[ -f "$ROM_FILE" ]]; then
  echo "   ✅ ROM already in place: $(du -h "$ROM_FILE" | cut -f1)" | tee -a "$LOGFILE"
elif [[ -f "$ROM_SOURCE" ]]; then
  echo "   📋 Copying ROM from roms/ → Starship/..." | tee -a "$LOGFILE"
  cp "$ROM_SOURCE" "$ROM_FILE"
  echo "   ✅ ROM copied: $(du -h "$ROM_FILE" | cut -f1)" | tee -a "$LOGFILE"
else
  echo "   ❌ ROM not found. Place it at:" | tee -a "$LOGFILE"
  echo "      $ROM_SOURCE  ← recommended" | tee -a "$LOGFILE"
  echo "      $ROM_FILE" | tee -a "$LOGFILE"
  exit 1
fi

# ── Step 6: CMake configure ───────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "⚙️  Step 6: CMake configure (Ninja, x86_64)" | tee -a "$LOGFILE"

# SDL2: prefer Homebrew's cmake config over /Library/Frameworks/SDL2.framework
# which has a broken sdl2-config.cmake on Tahoe (references /Library/Headers).
SDL2_CMAKE_DIR="$(brew --prefix sdl2 2>/dev/null)/lib/cmake/SDL2"
if [[ -d "$SDL2_CMAKE_DIR" ]]; then
  echo "   SDL2: using Homebrew ($(brew --prefix sdl2))" | tee -a "$LOGFILE"
  SDL2_FLAG="-DSDL2_DIR=$SDL2_CMAKE_DIR"
else
  echo "   SDL2: using system framework" | tee -a "$LOGFILE"
  SDL2_FLAG=""
fi

cmake -G Ninja \
  -B"$BUILD_DIR" \
  -S"$REPO_DIR" \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_BUILD_TYPE=Release \
  $SDL2_FLAG \
  2>&1 | tee -a "$LOGFILE"

# ── Step 7: Build ─────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔨 Step 7: Build ($(sysctl -n hw.logicalcpu) cores)" | tee -a "$LOGFILE"
cmake --build "$BUILD_DIR" --target Starship -j"$(sysctl -n hw.logicalcpu)" 2>&1 | tee -a "$LOGFILE"

# ── Step 8: Binary validation ─────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔍 Step 8: Validate binary" | tee -a "$LOGFILE"
if [[ ! -f "$BINARY" ]]; then
  echo "   ❌ Binary not found at: $BINARY" | tee -a "$LOGFILE"
  echo "   Build dir contents:" | tee -a "$LOGFILE"
  ls -lh "$BUILD_DIR" 2>/dev/null | tee -a "$LOGFILE"
  echo "   Check log: $LOGFILE" | tee -a "$LOGFILE"
  exit 1
fi
chmod +x "$BINARY"
echo "   ✅ Binary: $(file "$BINARY" | grep -o 'Mach-O.*')" | tee -a "$LOGFILE"
echo "   ✅ Size:   $(du -h "$BINARY" | cut -f1)" | tee -a "$LOGFILE"
echo "   ✅ Built:  $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$BINARY")" | tee -a "$LOGFILE"

# ── Step 9: Generate o2r assets ───────────────────────────────────────────────

# Upstream cmake defines ExtractAssets (sf64.o2r) and GeneratePortO2R (starship.o2r)
# as separate targets. They depend on TorchExternal (built automatically).
# Torch runs from the SOURCE dir and expects the ROM as baserom.z64, then
# cmake copies the .o2r files into the build dir.

echo "" | tee -a "$LOGFILE"
echo "🎮 Step 9: o2r assets (ExtractAssets + GeneratePortO2R)" | tee -a "$LOGFILE"

if [[ ! -f "$BUILD_DIR/sf64.o2r" ]]; then
  echo "   Building ExtractAssets (sf64.o2r via Torch)..." | tee -a "$LOGFILE"
  cmake --build "$BUILD_DIR" --target ExtractAssets 2>&1 | tee -a "$LOGFILE" || \
    echo "   ⚠️  ExtractAssets failed — sf64.o2r must be generated manually" | tee -a "$LOGFILE"
fi

if [[ ! -f "$BUILD_DIR/starship.o2r" ]]; then
  echo "   Building GeneratePortO2R (starship.o2r via Torch)..." | tee -a "$LOGFILE"
  cmake --build "$BUILD_DIR" --target GeneratePortO2R 2>&1 | tee -a "$LOGFILE" || \
    echo "   ⚠️  GeneratePortO2R failed — starship.o2r must be generated manually" | tee -a "$LOGFILE"
fi

if [[ -f "$BUILD_DIR/sf64.o2r" ]]; then
  echo "   ✅ sf64.o2r:     $(du -h "$BUILD_DIR/sf64.o2r" | cut -f1)" | tee -a "$LOGFILE"
else
  echo "   ❌ sf64.o2r not found — build cannot proceed" | tee -a "$LOGFILE"
fi

if [[ -f "$BUILD_DIR/starship.o2r" ]]; then
  echo "   ✅ starship.o2r: $(du -h "$BUILD_DIR/starship.o2r" | cut -f1)" | tee -a "$LOGFILE"
else
  echo "   ❌ starship.o2r not found — build cannot proceed" | tee -a "$LOGFILE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"
echo "✅ smca-build-macos.sh v$VERSION complete!" | tee -a "$LOGFILE"
echo "   📍 $BINARY" | tee -a "$LOGFILE"
echo "   📄 $LOGFILE" | tee -a "$LOGFILE"
echo "   👉 ./run-smca-macos.sh" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"