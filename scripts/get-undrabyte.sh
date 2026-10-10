#!/usr/bin/env bash
#
# get-undrabyte.sh - download, verify and (optionally) set up any UndraByte
# edition with one command. Self-contained: it needs only curl/wget and the
# usual coreutils, so you can run it on a fresh machine without the repo.
#
#   # pick an edition interactively, download + verify it:
#   ./get-undrabyte.sh
#
#   # a specific edition, straight to a folder:
#   ./get-undrabyte.sh --edition security --dir ~/isos
#
#   # download, verify, then write it to a USB stick (ERASES the stick):
#   ./get-undrabyte.sh --edition lite --write /dev/sdX
#
#   # download, verify, then boot it in a throwaway QEMU VM:
#   ./get-undrabyte.sh --edition minimal --vm
#
#   # just print the direct download links and exit (no download):
#   ./get-undrabyte.sh --edition full --links
#
# Editions: minimal lite server dev creator security gaming full
#
# Split images (the big editions) are downloaded as parts and rejoined for
# you, then the whole-ISO checksum is verified. Override the source repo with
# UNDRABYTE_REPO=owner/name.

set -euo pipefail

REPO="${UNDRABYTE_REPO:-undirboy/tuff-bi-67}"

BOLD=$'\033[1m'; RST=$'\033[0m'
RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; ACC=$'\033[38;5;38m'

die()  { printf '%serror:%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }
info() { printf '%s==>%s %s\n' "$BOLD" "$RST" "$*"; }
warn() { printf '%swarning:%s %s\n' "$YEL" "$RST" "$*" >&2; }
ok()   { printf '%s  ok%s %s\n' "$GRN" "$RST" "$*"; }
have() { command -v "$1" &>/dev/null; }

# edition -> release tag, and a one-line description.
edition_tag() {
    case $1 in
        minimal)  echo iso-minimal ;;
        lite)     echo iso-latest ;;   # the default/newest download
        server)   echo iso-server ;;
        dev)      echo iso-dev ;;
        creator)  echo iso-creator ;;
        security) echo iso-security ;;
        gaming)   echo iso-gaming ;;
        full)     echo iso-full ;;
        *)        return 1 ;;
    esac
}
edition_desc() {
    case $1 in
        minimal)  echo "smallest bootable base + desktop (~1.5 GB)" ;;
        lite)     echo "curated hacking/coding set for small machines (~2 GB)" ;;
        server)   echo "headless self-hosting base, no desktop (~2.5 GB)" ;;
        dev)      echo "toolchains, editors, containers (~4 GB)" ;;
        creator)  echo "video/audio/image/3D/streaming (~6 GB)" ;;
        security) echo "the full security toolkit + dev (~6 GB)" ;;
        gaming)   echo "Steam/Proton/Wine/emulation (~5 GB)" ;;
        full)     echo "everything (~9 GB)" ;;
    esac
}
EDITIONS=(minimal lite server dev creator security gaming full)

# ---------------------------------------------------------------- options --

EDITION=""
DIR="."
WRITE_DEV=""
DO_VM=0
LINKS_ONLY=0
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --edition) EDITION=${2:?}; shift 2 ;;
        --dir)     DIR=${2:?}; shift 2 ;;
        --write)   WRITE_DEV=${2:?}; shift 2 ;;
        --vm)      DO_VM=1; shift ;;
        --links)   LINKS_ONLY=1; shift ;;
        -y|--yes)  ASSUME_YES=1; shift ;;
        -h|--help) sed -n '3,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)         die "unknown argument: $1 (try --help)" ;;
    esac
done

# A downloader that works whether the machine has curl or wget.
if have curl; then
    dl()   { curl -fL# -o "$2" "$1"; }
    dlout(){ curl -fsSL "$1"; }
elif have wget; then
    dl()   { wget -q --show-progress -O "$2" "$1"; }
    dlout(){ wget -qO- "$1"; }
else
    die "need curl or wget"
fi

# ------------------------------------------------------------ choose one ---

choose_edition() {
    printf '%sUndraByte editions%s\n\n' "$BOLD$ACC" "$RST"
    local i=1 e
    for e in "${EDITIONS[@]}"; do
        printf '  %s%d%s  %-9s %s%s%s\n' "$ACC" "$i" "$RST" "$e" "$DIM" "$(edition_desc "$e")" "$RST"
        ((i++))
    done
    printf '\n'
    local choice
    read -rp "Pick an edition [1-${#EDITIONS[@]} or name]: " choice
    if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#EDITIONS[@]} )); then
        EDITION=${EDITIONS[choice-1]}
    else
        EDITION=$choice
    fi
}

[[ -z $EDITION && -t 0 ]] && choose_edition
[[ -n $EDITION ]] || die "no edition given (try --edition NAME, or run interactively)"

TAG="$(edition_tag "$EDITION")" || die "unknown edition '$EDITION' (one of: ${EDITIONS[*]})"

# ------------------------------------------------- resolve release assets --

info "looking up the '$EDITION' release ($TAG) in $REPO"
api="https://api.github.com/repos/$REPO/releases/tags/$TAG"
json="$(dlout "$api" 2>/dev/null || true)"
[[ -n $json && $json != *'"Not Found"'* ]] \
    || die "no published release for '$EDITION' yet (tag $TAG). Editions are published as they are built."

# Pull the asset download URLs out of the release JSON without needing jq.
mapfile -t URLS < <(printf '%s\n' "$json" \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | sed -E 's/.*"(https[^"]+)"/\1/')
(( ${#URLS[@]} )) || die "the release exists but has no downloadable assets yet"

if (( LINKS_ONLY )); then
    printf '\n%sDirect downloads for %s:%s\n' "$BOLD" "$EDITION" "$RST"
    printf '  %s\n' "${URLS[@]}"
    exit 0
fi

# --------------------------------------------------------------- download --

mkdir -p "$DIR"
cd "$DIR"
info "downloading ${#URLS[@]} file(s) into $(pwd)"
for u in "${URLS[@]}"; do
    name="${u##*/}"
    if [[ -f $name ]]; then
        ok "$name already present, skipping"
    else
        printf '%s  - %s%s\n' "$DIM" "$name" "$RST"
        dl "$u" "$name"
    fi
done

# --------------------------------------------------- reassemble + verify ---

iso=""
if compgen -G "*.iso.part*" >/dev/null; then
    base="$(ls ./*.iso.part* | head -1)"; base="${base##*/}"; base="${base%.part*}"
    info "rejoining split parts into $base"
    cat "$base".part* > "$base"
    iso="$base"
elif compgen -G "*.iso" >/dev/null; then
    iso="$(ls ./*.iso | head -1)"; iso="${iso##*/}"
fi
[[ -n $iso ]] || die "no .iso or split parts found after download"

if [[ -f SHA256SUMS ]] && have sha256sum; then
    info "verifying checksums"
    if sha256sum -c SHA256SUMS 2>/dev/null | grep -qE ":[[:space:]]*OK"; then
        ok "checksums verified"
    else
        warn "checksum verification reported a problem - re-run the download before using this image"
    fi
else
    warn "SHA256SUMS or sha256sum missing; skipping verification"
fi

ok "ready: $(pwd)/$iso"

# -------------------------------------------------------- optional setup ---

write_usb() {
    local dev=$1
    [[ -b $dev ]] || die "$dev is not a block device"
    local model size
    model="$(lsblk -ndo MODEL "$dev" 2>/dev/null | tr -s ' ')"
    size="$(lsblk -ndo SIZE "$dev" 2>/dev/null)"
    printf '\n%sABOUT TO ERASE %s%s  (%s %s)\n' "$RED$BOLD" "$dev" "$RST" "${model:-unknown}" "${size:-?}"
    printf '%sEverything on it will be destroyed.%s\n' "$YEL" "$RST"
    if (( ! ASSUME_YES )); then
        read -rp "Type the device path again to confirm ($dev): " c
        [[ $c == "$dev" ]] || die "confirmation did not match; nothing written"
    fi
    [[ $EUID -eq 0 ]] || die "writing to a disk needs root: re-run with sudo"
    info "writing $iso to $dev (this takes a while)"
    dd if="$iso" of="$dev" bs=4M conv=fsync status=progress
    sync
    ok "written. You can now boot $dev. See the USB guide for per-OS boot keys."
}

boot_vm() {
    have qemu-system-x86_64 || die "qemu not installed (install 'qemu' / 'qemu-system-x86' to use --vm)"
    local ovmf; ovmf="$(find / -name 'OVMF_CODE*.fd' 2>/dev/null | head -1)"
    info "booting $iso in QEMU (close the window to stop)"
    # shellcheck disable=SC2086
    qemu-system-x86_64 -machine q35 -m 4096 -smp 2 -enable-kvm \
        ${ovmf:+-drive if=pflash,format=raw,readonly=on,file="$ovmf"} \
        -cdrom "$iso" -boot d 2>/dev/null \
        || qemu-system-x86_64 -m 4096 -smp 2 -cdrom "$iso" -boot d
}

if [[ -n $WRITE_DEV ]]; then
    write_usb "$WRITE_DEV"
elif (( DO_VM )); then
    boot_vm
else
    cat <<EOF

${BOLD}Next:${RST}
  • Write to a USB stick:   sudo $0 --edition $EDITION --write /dev/sdX
  • Try it in a VM:         $0 --edition $EDITION --vm
  • Or point your VM software at: $(pwd)/$iso

Full write-to-USB and boot instructions (Windows, macOS, Linux):
  https://github.com/$REPO/blob/main/docs/WRITE-USB.md
EOF
fi
