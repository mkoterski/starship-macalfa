#!/bin/zsh
# smca-bundle-macos.sh
# starship-macalfa — Intel Mac / macOS Tahoe app bundle creator
#
# Wraps the compiled Starship binary into a proper Starship.app bundle.
# The binary is placed in Contents/MacOS/ behind a zsh wrapper that sets
# cwd to Contents/Resources/ so .o2r assets are found at runtime.
#
# Usage:
#   ./smca-bundle-macos.sh
#
# CHANGELOG
# v0.10 (2026-03-30) - Initial version; ported from bundle-macos.sh v0.10
#                      with pdmv conventions; placeholder .icns generation;
#                      cwd wrapper; Info.plist

set -e
VERSION="0.10"
SCRIPT_DIR="${0:A:h}"

REPO_DIR="$SCRIPT_DIR/Starship"
BUILD_DIR="$REPO_DIR/build-cmake"
BINARY="$BUILD_DIR/Starship"
BUNDLE="$BUILD_DIR/Starship.app"
ICONSET="$BUILD_DIR/macosx/starship.iconset"
ICNS="$BUILD_DIR/macosx/starship.icns"
ICON_SRC="$SCRIPT_DIR/smca-macalfa-icon.png"

LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/bundle-$(date '+%Y%m%d-%H%M').log"
mkdir -p "$LOG_DIR"

echo "🎁 smca-bundle-macos.sh v$VERSION — $(date)" | tee -a "$LOGFILE"

# ── Preflight checks ──────────────────────────────────────────────────────────

if [[ ! -f "$BINARY" ]]; then
  echo "❌ Starship binary not found — run ./smca-build-macos.sh first" | tee -a "$LOGFILE"
  exit 1
fi

for ASSET in sf64.o2r starship.o2r; do
  if [[ ! -f "$BUILD_DIR/$ASSET" ]]; then
    echo "❌ Missing asset: $ASSET — run ./smca-build-macos.sh first" | tee -a "$LOGFILE"
    exit 1
  fi
done
echo "✅ Preflight passed" | tee -a "$LOGFILE"

# ── Step 1: Generate .icns ────────────────────────────────────────────────────

# Prefer the build's iconset if available, fall back to smca-macalfa-icon.png
# via sips, and finally generate a dark navy placeholder.

echo "" | tee -a "$LOGFILE"
echo "🖼  Step 1: Generate .icns" | tee -a "$LOGFILE"

mkdir -p "$(dirname "$ICNS")"

if [[ -d "$ICONSET" ]]; then
  echo "   Using build iconset..." | tee -a "$LOGFILE"
  iconutil -c icns "$ICONSET" -o "$ICNS" 2>&1 | tee -a "$LOGFILE"
elif [[ -f "$ICON_SRC" ]]; then
  echo "   Generating from smca-macalfa-icon.png via sips..." | tee -a "$LOGFILE"
  ICONSET_TMP="$BUILD_DIR/macosx/starship.iconset"
  rm -rf "$ICONSET_TMP"
  mkdir -p "$ICONSET_TMP"
  for SIZE in 16 32 64 128 256 512 1024; do
    sips -z $SIZE $SIZE "$ICON_SRC" \
      --out "$ICONSET_TMP/icon_${SIZE}x${SIZE}.png" &>/dev/null
    if (( SIZE >= 32 )); then
      HALF=$(( SIZE / 2 ))
      cp "$ICONSET_TMP/icon_${SIZE}x${SIZE}.png" \
         "$ICONSET_TMP/icon_${HALF}x${HALF}@2x.png"
    fi
  done
  iconutil -c icns "$ICONSET_TMP" -o "$ICNS" 2>&1 | tee -a "$LOGFILE"
  rm -rf "$ICONSET_TMP"
else
  echo "   Generating placeholder .icns (dark navy)..." | tee -a "$LOGFILE"
  ICONSET_TMP="$(mktemp -d)/starship.iconset"
  mkdir -p "$ICONSET_TMP"
  python3 - "$ICONSET_TMP" << 'PYEOF'
import struct, zlib, sys, os
def mkpng(w, h):
    rows = bytearray()
    for y in range(h):
        rows += b'\x00'
        for x in range(w):
            rows += bytes([8, 12, 22, 255])
    compressed = zlib.compress(bytes(rows), 9)
    def chunk(name, data):
        c = zlib.crc32(name + data) & 0xffffffff
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', c)
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) +
            chunk(b'IDAT', compressed) +
            chunk(b'IEND', b''))
iconset = sys.argv[1]
for s in [16, 32, 64, 128, 256, 512]:
    with open(f'{iconset}/icon_{s}x{s}.png', 'wb') as f:     f.write(mkpng(s, s))
    with open(f'{iconset}/icon_{s}x{s}@2x.png', 'wb') as f:  f.write(mkpng(s*2, s*2))
PYEOF
  iconutil -c icns "$ICONSET_TMP" -o "$ICNS" 2>&1 | tee -a "$LOGFILE"
  rm -rf "$(dirname "$ICONSET_TMP")"
fi
echo "   ✅ starship.icns ($(du -h "$ICNS" | cut -f1))" | tee -a "$LOGFILE"

# ── Step 2: Bundle structure ──────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📁 Step 2: Creating bundle structure..." | tee -a "$LOGFILE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"
echo "   ✅ $BUNDLE created" | tee -a "$LOGFILE"

# ── Step 3: Binary + cwd wrapper ──────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📦 Step 3: Binary + wrapper..." | tee -a "$LOGFILE"
cp "$BINARY" "$BUNDLE/Contents/MacOS/StarshipBin"
chmod +x "$BUNDLE/Contents/MacOS/StarshipBin"

cat > "$BUNDLE/Contents/MacOS/Starship" << 'WRAPPER'
#!/bin/zsh
cd "${0:A:h}/../Resources"
exec "${0:A:h}/StarshipBin" "$@"
WRAPPER
chmod +x "$BUNDLE/Contents/MacOS/Starship"
echo "   ✅ Launcher wrapper created (cwd → Resources/)" | tee -a "$LOGFILE"

# ── Step 4: Icon ──────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🖼  Step 4: Icon..." | tee -a "$LOGFILE"
cp "$ICNS" "$BUNDLE/Contents/Resources/starship.icns"
echo "   ✅ starship.icns → Resources/" | tee -a "$LOGFILE"

# ── Step 5: Game assets ───────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📦 Step 5: Game assets..." | tee -a "$LOGFILE"
for ASSET in sf64.o2r starship.o2r; do
  cp "$BUILD_DIR/$ASSET" "$BUNDLE/Contents/Resources/$ASSET"
  echo "   ✅ $ASSET ($(du -h "$BUILD_DIR/$ASSET" | cut -f1))" | tee -a "$LOGFILE"
done

# gamecontrollerdb.txt and starship.cfg.json are optional at bundle time
for ASSET in gamecontrollerdb.txt starship.cfg.json; do
  if [[ -f "$BUILD_DIR/$ASSET" ]]; then
    cp "$BUILD_DIR/$ASSET" "$BUNDLE/Contents/Resources/$ASSET"
    echo "   ✅ $ASSET ($(du -h "$BUILD_DIR/$ASSET" | cut -f1))" | tee -a "$LOGFILE"
  fi
done

# ── Step 6: Info.plist ────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📄 Step 6: Info.plist..." | tee -a "$LOGFILE"
cat > "$BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>Starship</string>
  <key>CFBundleDisplayName</key>       <string>Starship</string>
  <key>CFBundleIdentifier</key>        <string>com.mkoterski.starship-macalfa</string>
  <key>CFBundleVersion</key>           <string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key>        <string>Starship</string>
  <key>CFBundleIconFile</key>          <string>starship</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>LSMinimumSystemVersion</key>    <string>12.0</string>
  <key>NSHighResolutionCapable</key>   <true/>
  <key>NSHumanReadableCopyright</key>  <string>HarbourMasters / mkoterski</string>
</dict>
</plist>
PLIST
echo "   ✅ Info.plist written (LSMinimumSystemVersion 12.0)" | tee -a "$LOGFILE"

# ── Step 7: Verify bundle ─────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔍 Step 7: Verify bundle..." | tee -a "$LOGFILE"
echo "   Binary:    $(file "$BUNDLE/Contents/MacOS/StarshipBin" | grep -o 'Mach-O.*')" | tee -a "$LOGFILE"
echo "   Icon:      $(du -h "$BUNDLE/Contents/Resources/starship.icns" | cut -f1)" | tee -a "$LOGFILE"
echo "   sf64.o2r:  $(du -h "$BUNDLE/Contents/Resources/sf64.o2r" | cut -f1)" | tee -a "$LOGFILE"
echo "   ship.o2r:  $(du -h "$BUNDLE/Contents/Resources/starship.o2r" | cut -f1)" | tee -a "$LOGFILE"
echo "   Bundle:    $(du -sh "$BUNDLE" | cut -f1) total" | tee -a "$LOGFILE"

echo "" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"
echo "✅ smca-bundle-macos.sh v$VERSION complete!" | tee -a "$LOGFILE"
echo "   📍 $BUNDLE" | tee -a "$LOGFILE"
echo "   👉 Test by double-clicking, then run ./smca-package-macos.sh" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"