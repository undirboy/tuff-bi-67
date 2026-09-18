#!/usr/bin/env bash
#
# Check every name in packages/*.list against the real Arch repositories.
#
# Package names drift: things get renamed (vulkan-mesa-layers -> vulkan-swrast),
# moved to the AUR, or dropped. A typo here only shows up 40 minutes into a
# build, so check first.
#
#   ./scripts/verify-packages.sh            # uses the local pacman
#   ./scripts/verify-packages.sh --docker   # uses an archlinux container
#
# Exits non-zero if any name in the official lists cannot be resolved.
# aur-optional.list and 90-blackarch.list are reported but never fatal:
# they are not expected to exist in core/extra/multilib.

set -uo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/lib/common.sh"

ROOT="$(repo_root)"
USE_DOCKER=0
[[ ${1-} == --docker ]] && USE_DOCKER=1

if (( USE_DOCKER )); then
    command -v docker &>/dev/null || die "docker not found"
    log "checking inside an archlinux container"
    exec docker run --rm -v "$ROOT:/repo:ro" -w /repo archlinux:latest \
        bash -c "sed -i '/^#\\[multilib\\]/,+1 s/^#//' /etc/pacman.conf && \
                 pacman -Sy --noconfirm >/dev/null && /repo/scripts/verify-packages.sh"
fi

command -v pacman &>/dev/null || die "pacman not found - run with --docker on a non-Arch host"

log "refreshing the package databases"
pacman -Sy &>/dev/null || warn "could not refresh databases; results may be stale"

if ! pacman -Sl multilib &>/dev/null; then
    warn "[multilib] is not enabled here, so every lib32-* name will look missing"
fi

declare -A KNOWN=()
while read -r _repo name _ver _rest; do
    KNOWN[$name]=1
done < <(pacman -Sl 2>/dev/null)

log "${#KNOWN[@]} packages visible across the enabled repositories"

missing_required=0
shopt -s nullglob
for list in "$ROOT"/packages/*.list; do
    base="$(basename "$list")"
    optional=0
    [[ $base == aur-optional.list || $base == 90-blackarch.list ]] && optional=1

    missing=()
    while read -r pkg; do
        [[ -n ${KNOWN[$pkg]-} ]] && continue
        # A name can also be satisfied as a virtual provider (e.g. 'sh').
        pacman -Si "$pkg" &>/dev/null && continue
        [[ -n "$(pacman -Ssq "^${pkg}$" 2>/dev/null)" ]] && continue
        missing+=("$pkg")
    done < <(grep -vE '^[[:space:]]*(#|$)' "$list")

    if (( ${#missing[@]} == 0 )); then
        ok "$base"
    elif (( optional )); then
        printf '%s note%s %s: not in the official repos (expected): %s\n' \
            "$C_DIM" "$C_RST" "$base" "${missing[*]}"
    else
        printf '%sFAIL%s %s: %d unresolved name(s)\n' "$C_RED" "$C_RST" "$base" "${#missing[@]}"
        printf '       %s\n' "${missing[@]}"
        missing_required=$(( missing_required + ${#missing[@]} ))
    fi
done

printf '\n'
if (( missing_required )); then
    printf '%s%d package name(s) do not resolve.%s\n' "$C_RED" "$missing_required" "$C_RST"
    printf 'Search for the new name with: pacman -Ss <partial>   (or check the AUR)\n'
    exit 1
fi
printf '%sEvery required package name resolves.%s\n' "$C_GRN" "$C_RST"
