#!/usr/bin/env bash
#
# Add the Flathub remote once the network is up, so the Software app (and
# `flatpak install`) can offer the large Flatpak catalogue for apps that are
# not in the Arch repos. Best-effort and idempotent: it is a no-op once the
# remote exists, and it simply does nothing (exit 0) when offline, so the
# oneshot service can try again on the next boot.

set -uo pipefail

command -v flatpak >/dev/null 2>&1 || exit 0

flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

exit 0
