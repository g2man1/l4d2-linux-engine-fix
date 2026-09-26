#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "============================================================"
echo " Left 4 Dead 2 Linux Engine Crash Fix - Installer"
echo " Fixes strdup/strlen(NULL) crashes in engine.so & server.so"
echo "============================================================"

SO_SOURCE="$DIR/bin/libl4d2_engine_fix.so"
if [ ! -f "$SO_SOURCE" ]; then
    echo "[!] Error: '$SO_SOURCE' not found."
    exit 1
fi

TARGET_LIB_DIR="$HOME/.local/lib"
mkdir -p "$TARGET_LIB_DIR"
cp -f "$SO_SOURCE" "$TARGET_LIB_DIR/libl4d2_engine_fix.so"
echo "[+] Copied libl4d2_engine_fix.so -> $TARGET_LIB_DIR/libl4d2_engine_fix.so"

POSSIBLE_PATHS=(
    "$HOME/.local/share/Steam/steamapps/common/Left 4 Dead 2"
    "$HOME/.steam/steam/steamapps/common/Left 4 Dead 2"
    "$HOME/.steam/root/steamapps/common/Left 4 Dead 2"
    "$HOME/.steam/debian-installation/steamapps/common/Left 4 Dead 2"
)

L4D2_ROOT=""
for p in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$p" ] && [ -f "$p/hl2.sh" ]; then
        L4D2_ROOT="$p"
        break
    fi
done

if [ -n "$L4D2_ROOT" ]; then
    HL2_SH="$L4D2_ROOT/hl2.sh"
    echo "[+] Found Left 4 Dead 2 at: $L4D2_ROOT"

    if grep -q "libl4d2_engine_fix.so" "$HL2_SH"; then
        echo "[+] hl2.sh is already configured with LD_PRELOAD."
    else
        if [ ! -f "$HL2_SH.bak" ]; then
            cp "$HL2_SH" "$HL2_SH.bak"
            echo "[+] Backup created: hl2.sh.bak"
        fi

        LINE='export LD_PRELOAD="$HOME/.local/lib/libl4d2_engine_fix.so${LD_PRELOAD:+:$LD_PRELOAD}"'
        sed -i '/STATUS=42/i # Fix for Valve Linux engine crash (strdup/strlen NULL pointer in MP3 parser & filesystem)\n'"$LINE"'\n' "$HL2_SH"
        echo "[+] hl2.sh updated successfully."
    fi
else
    echo "[!] Left 4 Dead 2 installation not found in standard paths."
    echo "    You can still use this fix via Steam Launch Options:"
    echo "    LD_PRELOAD=\"\$HOME/.local/lib/libl4d2_engine_fix.so\" %command%"
fi

echo ""
echo "============================================================"
echo " [OK] Installation completed successfully!"
echo ""
echo " Alternative (Permanent via Steam Launch Options):"
echo " In Steam -> Right click Left 4 Dead 2 -> Properties -> Launch Options:"
echo "   LD_PRELOAD=\"\$HOME/.local/lib/libl4d2_engine_fix.so\" %command%"
echo "============================================================"
