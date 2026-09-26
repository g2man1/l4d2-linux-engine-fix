#!/usr/bin/env bash
set -e

echo "============================================================"
echo " Left 4 Dead 2 Linux Engine Crash Fix - Uninstaller"
echo "============================================================"

POSSIBLE_PATHS=(
    "$HOME/.local/share/Steam/steamapps/common/Left 4 Dead 2"
    "$HOME/.steam/steam/steamapps/common/Left 4 Dead 2"
    "$HOME/.steam/root/steamapps/common/Left 4 Dead 2"
    "$HOME/.steam/debian-installation/steamapps/common/Left 4 Dead 2"
)

for p in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$p/hl2.sh.bak" ]; then
        cp -f "$p/hl2.sh.bak" "$p/hl2.sh"
        echo "[+] Restored original hl2.sh from backup in: $p"
    elif [ -f "$p/hl2.sh" ]; then
        sed -i '/libl4d2_engine_fix.so/d' "$p/hl2.sh"
        echo "[+] Removed LD_PRELOAD lines from hl2.sh in: $p"
    fi
done

if [ -f "$HOME/.local/lib/libl4d2_engine_fix.so" ]; then
    rm -f "$HOME/.local/lib/libl4d2_engine_fix.so"
    echo "[+] Removed $HOME/.local/lib/libl4d2_engine_fix.so"
fi

echo ""
echo "============================================================"
echo " [OK] Uninstallation complete. Game restored to original state."
echo " If you configured Steam Launch Options, remember to remove:"
echo "   LD_PRELOAD=\"\$HOME/.local/lib/libl4d2_engine_fix.so\" %command%"
echo "============================================================"
