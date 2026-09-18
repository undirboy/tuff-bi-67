#!/usr/bin/env bash
#
# Build a HexForge Linux ISO.
#
# The repository holds an archiso profile with a *generated* package list:
# this script stages a copy of profile/, writes packages.x86_64 from the
# manifests in packages/, wires up the display manager for the chosen
# desktop, and then calls mkarchiso.
#
#   ./scripts/build-iso.sh                         # full edition, KDE
#   ./scripts/build-iso.sh --edition security      # no gaming stack
#   ./scripts/build-iso.sh --desktop xfce --vm-only
#   ./scripts/build-iso.sh --with-blackarch        # + thousands of tools
#   ./scripts/build-iso.sh --docker                # build on a non-Arch host
#   ./scripts/build-iso.sh --list-packages         # dry run, print the set
#
# Requirements on the host: Arch Linux (or --docker), root, and `archiso`.

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/lib/common.sh"

ROOT="$(repo_root)"
PKGDIR="$ROOT/packages"
PROFILE_SRC="$ROOT/profile"

EDITION=full
DESKTOP=kde
OUT_DIR="$ROOT/out"
WORK_DIR="$ROOT/work"
STAGE_DIR="$ROOT/build/profile"
KEEP_WORK=0
LIST_ONLY=0
STAGE_ONLY=0
SKIP_PREFLIGHT=0
USE_DOCKER=0
IN_CONTAINER=0
export HEXFORGE_VM_ONLY=0
export HEXFORGE_WITH_BLACKARCH=0
export HEXFORGE_WITH_NVIDIA=0

usage() {
    sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    cat <<EOF

Options
  --edition NAME     full (default), security, dev, gaming, lite, minimal
  --desktop NAME     kde (default), xfce, none
  --vm-only          drop hardware firmware; smaller ISO for VM-only use
  --with-blackarch   add the BlackArch repo and four large tool groups
  --with-nvidia      add the proprietary NVIDIA driver
  --out DIR          where the ISO lands (default: out/)
  --work DIR         scratch directory (default: work/)
  --keep-work        do not delete the work directory afterwards
  --list-packages    print the resolved package set and exit
  --skip-preflight   do not check package names against the repositories first
  --stage-only       stage the profile and generate packages.x86_64, then stop
                     (useful for inspecting exactly what mkarchiso would see)
  --docker           run the build inside an archlinux container
  -h, --help         this text
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --edition)        EDITION=${2:?}; shift 2 ;;
        --desktop)        DESKTOP=${2:?}; shift 2 ;;
        --vm-only)        HEXFORGE_VM_ONLY=1; shift ;;
        --with-blackarch) HEXFORGE_WITH_BLACKARCH=1; shift ;;
        --with-nvidia)    HEXFORGE_WITH_NVIDIA=1; shift ;;
        --out)            OUT_DIR=${2:?}; shift 2 ;;
        --work)           WORK_DIR=${2:?}; shift 2 ;;
        --keep-work)      KEEP_WORK=1; shift ;;
        --list-packages)  LIST_ONLY=1; shift ;;
        --skip-preflight) SKIP_PREFLIGHT=1; shift ;;
        --stage-only)     STAGE_ONLY=1; shift ;;
        --docker)         USE_DOCKER=1; shift ;;
        --in-container)   IN_CONTAINER=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        *)                usage >&2; die "unknown option: $1" ;;
    esac
done

case $DESKTOP in kde|xfce|none) ;; *) die "unknown desktop '$DESKTOP' (kde, xfce, none)" ;; esac
[[ -r "$PKGDIR/30-desktop-$DESKTOP.list" ]] || die "no package list for desktop '$DESKTOP'"

VERSION="$(< "$ROOT/VERSION")"

mapfile -t LISTS < <(edition_lists "$EDITION" "$DESKTOP" "$PKGDIR")
mapfile -t PACKAGES < <(resolve_packages "${LISTS[@]}")

if (( LIST_ONLY )); then
    printf '%s\n' "${PACKAGES[@]}"
    printf '\n%s%d packages%s from %d lists (edition=%s desktop=%s)\n' \
        "$C_DIM" "${#PACKAGES[@]}" "$C_RST" "${#LISTS[@]}" "$EDITION" "$DESKTOP" >&2
    exit 0
fi

# ------------------------------------------------------------------ docker --

if (( USE_DOCKER )); then
    command -v docker &>/dev/null || die "docker not found"
    log "building inside an archlinux container (privileged: mkarchiso needs loop devices)"
    exec docker run --rm --privileged \
        -v "$ROOT:/repo" -w /repo \
        archlinux:latest \
        bash -c "pacman -Sy --noconfirm --needed archiso git && \
                 /repo/scripts/build-iso.sh --in-container \
                   --edition '$EDITION' --desktop '$DESKTOP' \
                   $( ((HEXFORGE_VM_ONLY))        && echo --vm-only ) \
                   $( ((HEXFORGE_WITH_BLACKARCH)) && echo --with-blackarch ) \
                   $( ((HEXFORGE_WITH_NVIDIA))    && echo --with-nvidia ) \
                   $( ((KEEP_WORK))               && echo --keep-work )"
fi

# ------------------------------------------------------------ host checks --

if (( IN_CONTAINER )); then
    log "running inside the archlinux build container"
    if [[ ! -d /etc/pacman.d/gnupg ]]; then
        pacman-key --init
        pacman-key --populate archlinux
    fi
fi

if (( ! STAGE_ONLY )); then
    [[ $EUID -eq 0 ]] || die "mkarchiso needs root. Re-run with sudo, or use --docker."
    command -v mkarchiso &>/dev/null || die "mkarchiso not found. Install the 'archiso' package, or use --docker."
    [[ -e /dev/loop-control ]] || warn "no /dev/loop-control: the build will fail unless the container is privileged"
fi

free_kb="$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
if (( free_kb < 25 * 1024 * 1024 )); then
    warn "only $(human_size $((free_kb * 1024))) free; a full build wants 25 GB or more"
fi

# --------------------------------------------------------------- staging --

log "staging profile -> $STAGE_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$(dirname "$STAGE_DIR")"
cp -a "$PROFILE_SRC" "$STAGE_DIR"

printf '%s\n' "$VERSION" > "$STAGE_DIR/version"

log "writing packages.x86_64 (${#PACKAGES[@]} packages)"
{
    printf '# Generated by scripts/build-iso.sh - do not edit.\n'
    printf '# edition=%s desktop=%s vm_only=%s blackarch=%s nvidia=%s version=%s\n\n' \
        "$EDITION" "$DESKTOP" "$HEXFORGE_VM_ONLY" "$HEXFORGE_WITH_BLACKARCH" \
        "$HEXFORGE_WITH_NVIDIA" "$VERSION"
    printf '%s\n' "${PACKAGES[@]}"
} > "$STAGE_DIR/packages.x86_64"

if (( HEXFORGE_WITH_BLACKARCH )); then
    log "adding the blackarch repository to the build pacman.conf"
    cat >> "$STAGE_DIR/pacman.conf" <<'EOF'

[blackarch]
SigLevel = Required DatabaseOptional
Server = https://blackarch.org/blackarch/$repo/os/$arch
EOF
    if ! pacman-key --list-keys blackarch &>/dev/null; then
        die "the blackarch keyring is not installed on this build host.
     Install it first:  curl -O https://blackarch.org/strap.sh && chmod +x strap.sh && ./strap.sh
     (verify the checksum against https://blackarch.org/downloads.html first)"
    fi
fi

# Display manager wiring depends on the desktop, so it is generated rather
# than committed: shipping a dangling sddm symlink on an XFCE image would
# leave the machine without a login screen.
airootfs="$STAGE_DIR/airootfs"
case $DESKTOP in
    kde)  dm_unit=/usr/lib/systemd/system/sddm.service ;;
    xfce) dm_unit=/usr/lib/systemd/system/lightdm.service ;;
    none) dm_unit="" ;;
esac

if [[ -n $dm_unit ]]; then
    mkdir -p "$airootfs/etc/systemd/system/graphical.target.wants"
    ln -sfn "$dm_unit" "$airootfs/etc/systemd/system/display-manager.service"
    ln -sfn "$dm_unit" "$airootfs/etc/systemd/system/graphical.target.wants/display-manager.service"
    ln -sfn /usr/lib/systemd/system/graphical.target "$airootfs/etc/systemd/system/default.target"
    log "default target: graphical ($(basename "$dm_unit"))"
else
    ln -sfn /usr/lib/systemd/system/multi-user.target "$airootfs/etc/systemd/system/default.target"
    log "default target: multi-user (headless image)"
fi

# The installer and the toolkit on the ISO read these at runtime.
install -d "$airootfs/usr/local/share/hexforge"
cp -a "$PKGDIR" "$airootfs/usr/local/share/hexforge/packages"
cp -a "$ROOT/docs" "$airootfs/usr/local/share/hexforge/docs"
install -Dm0644 "$ROOT/README.md" "$airootfs/usr/local/share/hexforge/README.md"

if (( STAGE_ONLY )); then
    ok "staged profile at $STAGE_DIR (${#PACKAGES[@]} packages)"
    printf '\nRun mkarchiso against it with:\n  %ssudo mkarchiso -v -w %s -o %s %s%s\n' \
        "$C_DIM" "$WORK_DIR" "$OUT_DIR" "$STAGE_DIR" "$C_RST"
    exit 0
fi

# -------------------------------------------------------------- preflight --

# Arch is a rolling release: names get renamed, split, or dropped to the AUR.
# Finding that out 40 minutes into a build is the expensive way. Syncing the
# databases and checking the whole set takes a few seconds.
if (( ! SKIP_PREFLIGHT )); then
    log "checking ${#PACKAGES[@]} package names against the repositories"
    preflight_db="$WORK_DIR/preflight-db"
    mkdir -p "$WORK_DIR"
    index="$WORK_DIR/preflight-index"
    if repo_package_index "$STAGE_DIR/pacman.conf" "$preflight_db" > "$index"; then
        mapfile -t MISSING < <(missing_packages "$index" "$STAGE_DIR/pacman.conf" \
                                                "$preflight_db" "${PACKAGES[@]}")
        if (( ${#MISSING[@]} )); then
            printf '\n%s%d package name(s) do not resolve:%s\n' "$C_RED" "${#MISSING[@]}" "$C_RST" >&2
            printf '  %s\n' "${MISSING[@]}" >&2
            cat >&2 <<EOF

Nothing has been built. Fix the names in packages/*.list, then try again.
  find the new name:   pacman -Ss <partial>
  moved to the AUR:    move the line to packages/aur-optional.list
  check them all:      ./scripts/verify-packages.sh
  build anyway:        --skip-preflight
EOF
            exit 1
        fi
        ok "every package name resolves"
    else
        warn "could not sync the package databases for the preflight check; continuing"
    fi
    rm -rf "$preflight_db" "$index"
fi

# ----------------------------------------------------------------- build --

mkdir -p "$OUT_DIR" "$WORK_DIR"
log "running mkarchiso (this takes 20-60 minutes and downloads several GB)"
printf '%s    edition=%s desktop=%s version=%s packages=%d%s\n' \
    "$C_DIM" "$EDITION" "$DESKTOP" "$VERSION" "${#PACKAGES[@]}" "$C_RST"

start=$SECONDS
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$STAGE_DIR"
elapsed=$(( SECONDS - start ))

if (( ! KEEP_WORK )); then
    log "cleaning $WORK_DIR"
    rm -rf "${WORK_DIR:?}"
fi

iso="$(find "$OUT_DIR" -maxdepth 1 -name 'hexforge-*.iso' -printf '%T@ %p\n' \
        | sort -rn | head -1 | cut -d' ' -f2-)"

printf '\n'
if [[ -n $iso ]]; then
    ok "$iso  ($(human_size "$(stat -c%s "$iso")"), built in $((elapsed / 60))m $((elapsed % 60))s)"
    printf '\nBoot it:\n  %s./scripts/run-vm.sh %s%s\n' "$C_DIM" "$iso" "$C_RST"
else
    die "mkarchiso finished but no ISO was found in $OUT_DIR"
fi
