#!/usr/bin/env bash
#
# Best-effort first-boot install of Brave (the primary browser) from the AUR.
#
# Brave is not in the official repositories, so it cannot ship inside the ISO.
# This runs once, in the background, after the network is up: if the machine
# is online and Brave is not already present, it builds brave-bin as the live
# user. It is deliberately non-fatal and is NOT ordered before the desktop, so
# it can never delay or block boot - until Brave lands, Firefox is the
# fallback (see undrabyte-brave).

set -uo pipefail

LIVE_USER=forge

log() { printf 'install-brave: %s\n' "$*"; }

# Already installed? Nothing to do.
if command -v brave >/dev/null 2>&1 || command -v brave-browser >/dev/null 2>&1; then
    log "Brave already present, nothing to do."
    exit 0
fi

# Need the unprivileged build user to exist (created by live-setup).
if ! id -u "$LIVE_USER" >/dev/null 2>&1; then
    log "live user '$LIVE_USER' not present yet; skipping."
    exit 0
fi

online() {
    curl -fsS --max-time 8 -o /dev/null https://aur.archlinux.org/ 2>/dev/null && return 0
    ping -c1 -W3 1.1.1.1 >/dev/null 2>&1
}

if ! online; then
    log "offline; leaving Firefox as the browser for now."
    exit 0
fi

# undrabyte-toolkit's AUR path builds as $SUDO_USER and runs pacman as root.
# We are already root here, so set the builder explicitly to the live user.
log "installing brave-bin from the AUR as '$LIVE_USER' (background, best effort)…"
export SUDO_USER="$LIVE_USER"
if /usr/local/bin/undrabyte-toolkit aur brave-bin; then
    log "Brave installed."
else
    log "Brave install did not complete; Firefox remains the fallback."
fi
exit 0
