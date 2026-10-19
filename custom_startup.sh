#!/usr/bin/env bash
# Keep Prism Launcher running full-screen, modelled on kasmweb/minetest's startup.
set -e
START_COMMAND="/usr/local/bin/prismlauncher"
PGREP="prismlauncher"
export MAXIMIZE="true"
export MAXIMIZE_NAME="Prism Launcher"
MAXIMIZE_SCRIPT=$STARTUPDIR/maximize_window.sh

# A persistent profile keeps its own prismlauncher.cfg, which overrides the
# image's. Make sure the game always starts through the GPU wrapper.
CFG="$HOME/.local/share/PrismLauncher/prismlauncher.cfg"
if [ -f "$CFG" ] && ! grep -q '^WrapperCommand=.' "$CFG"; then
    sed -i '/^WrapperCommand=/d; /^\[General\]/a WrapperCommand=/usr/local/bin/mc-gpu' "$CFG"
fi

# Baked images: copy instances the profile doesn't have yet (e.g. after the image
# moves to a new Minecraft release), without touching existing ones or worlds.
DEF=/home/kasm-default-profile/.local/share/PrismLauncher
if [ -d "$DEF/instances" ] && [ "$HOME" != /home/kasm-default-profile ]; then
    mkdir -p "$HOME/.local/share/PrismLauncher/instances"
    for i in "$DEF"/instances/*/; do
        n=$(basename "$i")
        [ -e "$HOME/.local/share/PrismLauncher/instances/$n" ] || cp -a "$i" "$HOME/.local/share/PrismLauncher/instances/$n"
    done
fi

if [ -n "$DISABLE_CUSTOM_STARTUP" ]; then
    exit 0
fi

while true; do
    if ! pgrep -f "$PGREP" > /dev/null; then
        /usr/bin/filter_ready
        /usr/bin/desktop_ready
        set +e
        bash "$MAXIMIZE_SCRIPT" &
        source "$STARTUPDIR/generate_container_user"
        $START_COMMAND
        set -e
    fi
    sleep 1
done
