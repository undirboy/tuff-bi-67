#!/usr/bin/env bash
# Shared helpers for the HexForge build scripts. Sourced, never executed.

# shellcheck disable=SC2034
HEXFORGE_COMMON_SOURCED=1

if [[ -t 1 ]]; then
    C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RED=$'\033[31m'
    C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_RST=$'\033[0m'
else
    C_BOLD=''; C_DIM=''; C_RED=''; C_GRN=''; C_YEL=''; C_RST=''
fi

log()  { printf '%s==>%s %s\n' "$C_BOLD" "$C_RST" "$*"; }
ok()   { printf '%s ok %s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%swarning:%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

repo_root() {
    local here
    here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
    printf '%s\n' "$here"
}

# Editions map to a set of package lists. Keep this the single source of
# truth: hexforge-install (on the ISO) mirrors it for installed systems.
edition_lists() {
    local edition=$1 desktop=$2 pkgdir=$3
    local -a lists=("$pkgdir/00-base.list" "$pkgdir/20-vm-guest.list")

    [[ ${HEXFORGE_VM_ONLY:-0} == 1 ]] || lists+=("$pkgdir/10-hardware.list")
    [[ $desktop != none ]] && lists+=("$pkgdir/30-desktop-$desktop.list")

    case $edition in
        minimal)  ;;
        lite)     lists+=("$pkgdir/45-lite.list") ;;
        dev)      lists+=("$pkgdir/40-dev.list" "$pkgdir/70-extras.list") ;;
        security) lists+=("$pkgdir/40-dev.list" "$pkgdir/50-security.list" "$pkgdir/70-extras.list") ;;
        gaming)   lists+=("$pkgdir/60-gaming.list" "$pkgdir/70-extras.list") ;;
        full)     lists+=("$pkgdir/40-dev.list" "$pkgdir/50-security.list"
                          "$pkgdir/60-gaming.list" "$pkgdir/70-extras.list") ;;
        *)        die "unknown edition '$edition' (full, security, dev, gaming, lite, minimal)" ;;
    esac

    [[ ${HEXFORGE_WITH_BLACKARCH:-0} == 1 ]] && lists+=("$pkgdir/90-blackarch.list")
    [[ ${HEXFORGE_WITH_NVIDIA:-0}    == 1 ]] && lists+=("$pkgdir/95-nvidia.list")

    printf '%s\n' "${lists[@]}"
}

# Strip comments and blank lines, de-duplicate, keep deterministic order.
resolve_packages() {
    local -a lists=("$@")
    local l
    for l in "${lists[@]}"; do
        [[ -r $l ]] || die "package list not found: $l"
    done
    grep -hvE '^[[:space:]]*(#|$)' "${lists[@]}" \
        | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//' \
        | grep -v '^$' \
        | sort -u
}

human_size() {
    local bytes=$1
    awk -v b="$bytes" 'BEGIN {
        split("B KiB MiB GiB TiB", u, " ");
        i = 1; while (b >= 1024 && i < 5) { b /= 1024; i++ }
        printf "%.1f %s", b, u[i]
    }'
}

# Names visible across the repositories a given pacman.conf enables, synced
# into a throwaway database so nothing on the build host is touched.
# Usage: repo_package_index <conf> <dbpath>
repo_package_index() {
    local conf=$1 dbpath=$2
    mkdir -p "$dbpath"
    pacman --config "$conf" --dbpath "$dbpath" -Sy &>/dev/null || return 1
    pacman --config "$conf" --dbpath "$dbpath" -Sl 2>/dev/null | awk '{print $2}'
}

# Print the names in $3.. that the index in $1 does not contain. A name can
# also be satisfied by a virtual provider, so unknown names get a second look.
missing_packages() {
    local index_file=$1 conf=$2 dbpath=$3
    shift 3
    local pkg
    for pkg in "$@"; do
        grep -qxF "$pkg" "$index_file" && continue
        pacman --config "$conf" --dbpath "$dbpath" -Si "$pkg" &>/dev/null && continue
        printf '%s\n' "$pkg"
    done
}
