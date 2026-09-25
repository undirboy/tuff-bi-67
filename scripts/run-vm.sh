#!/usr/bin/env bash
#
# Boot a UndraByte ISO (or an installed disk image) under QEMU with settings
# that actually work: KVM when available, UEFI by default, virtio everywhere,
# and OpenGL passthrough so the desktop is not stuck on llvmpipe.
#
#   ./scripts/run-vm.sh                          # newest ISO in out/, live
#   ./scripts/run-vm.sh out/undrabyte-2026.01.iso
#   ./scripts/run-vm.sh --disk vm/undrabyte.qcow2 --size 80G   # install target
#   ./scripts/run-vm.sh --disk vm/undrabyte.qcow2 --no-iso     # boot installed
#   ./scripts/run-vm.sh --share ~/work                        # 9p host folder

set -euo pipefail

_self="${BASH_SOURCE[0]}"
[[ -L $_self ]] && _self="$(readlink "$_self")"
_here="$(cd -- "$(dirname -- "$_self")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$_here/lib/common.sh"

ROOT="$(repo_root)"
HOST_OS="$(uname -s)"

ISO=""
DISK=""
DISK_SIZE=60G
RAM=""
CPUS=""
FIRMWARE=uefi
GL=auto
SHARE=""
SSH_PORT=2222
NO_ISO=0
USB_IDS=()
EXTRA=()

usage() {
    cat <<EOF
${C_BOLD}run-vm.sh${C_RST} [ISO] [options]

  --disk FILE      qcow2 disk to attach; created if missing
  --size SIZE      size for a newly created disk (default: $DISK_SIZE)
  --ram SIZE       guest memory (default: half the host's, 4-8 GB)
  --cpus N         guest vCPUs (default: half the host's, at least 2)
  --bios           boot with SeaBIOS instead of UEFI
  --uefi           boot with OVMF (default)
  --gl / --no-gl   force virgl 3D on or off (default: on when the host allows)
  --share DIR      export DIR to the guest over 9p (mount tag: hostshare)
  --ssh-port N     forward host port N to guest :22 (default: $SSH_PORT)
  --usb VID:PID    pass a host USB device through to the guest (repeatable);
                   this is how a monitor-mode WiFi adapter reaches the VM
  --wifi           list USB WiFi-capable adapters and pass the one you pick
                   through (needs lsusb; a shortcut for --usb)
  --no-iso         do not attach an ISO (boot the disk)
  --               everything after this is passed straight to qemu

Inside the guest, mount a --share with:
  ${C_DIM}sudo mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt${C_RST}

A VM's virtio NIC cannot do monitor mode or packet injection. To capture a
WPA handshake from your own access point, pass a real USB WiFi adapter through:
  ${C_DIM}./scripts/run-vm.sh --disk vm/undrabyte.qcow2 --wifi${C_RST}
then, in the guest: ${C_DIM}undrabyte-wifi${C_RST}
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --disk)     DISK=${2:?}; shift 2 ;;
        --size)     DISK_SIZE=${2:?}; shift 2 ;;
        --ram)      RAM=${2:?}; shift 2 ;;
        --cpus)     CPUS=${2:?}; shift 2 ;;
        --bios)     FIRMWARE=bios; shift ;;
        --uefi)     FIRMWARE=uefi; shift ;;
        --gl)       GL=on; shift ;;
        --no-gl)    GL=off; shift ;;
        --share)    SHARE=${2:?}; shift 2 ;;
        --ssh-port) SSH_PORT=${2:?}; shift 2 ;;
        --usb)      USB_IDS+=("${2:?}"); shift 2 ;;
        --wifi)     USB_IDS+=("__pick_wifi__"); shift ;;
        --no-iso)   NO_ISO=1; shift ;;
        --)         shift; EXTRA=("$@"); break ;;
        -h|--help)  usage; exit 0 ;;
        -*)         usage >&2; die "unknown option: $1" ;;
        *)          ISO=$1; shift ;;
    esac
done

command -v qemu-system-x86_64 &>/dev/null || die "qemu-system-x86_64 not found (install qemu-full / qemu-system-x86)"

# ------------------------------------------------- size the guest to the host --

host_ram_gb() {
    case $HOST_OS in
        Linux)  awk '/MemTotal/{printf "%d", $2/1048576}' /proc/meminfo ;;
        Darwin) echo $(( $(sysctl -n hw.memsize) / 1073741824 )) ;;
        *)      echo 8 ;;
    esac
}
host_cpus() {
    case $HOST_OS in
        Linux)  nproc ;;
        Darwin) sysctl -n hw.logicalcpu ;;
        *)      echo 2 ;;
    esac
}

if [[ -z $RAM ]]; then
    _hr=$(host_ram_gb); _gr=$(( _hr / 2 ))
    (( _gr < 4 )) && _gr=4
    (( _gr > 8 )) && _gr=8
    RAM="${_gr}G"
    log "guest memory: $RAM (half of the host's ${_hr} GB; override with --ram)"
    (( _hr < 8 )) && warn "the host has only ${_hr} GB; giving the guest ${_gr} GB will squeeze it"
fi
if [[ -z $CPUS ]]; then
    _hc=$(host_cpus); CPUS=$(( _hc / 2 ))
    (( CPUS < 2 )) && CPUS=2
    log "guest vCPUs: $CPUS (of the host's $_hc; override with --cpus)"
fi

# ---------------------------------------------------------------- the ISO --

if (( ! NO_ISO )) && [[ -z $ISO ]]; then
    # shellcheck disable=SC2012  # ls -t is the portable way to sort by mtime;
    # BSD find has no -printf, and these are paths we generated ourselves.
    ISO="$(ls -t "$ROOT"/out/*.iso 2>/dev/null | head -1)"
    [[ -n $ISO ]] || die "no ISO found in $ROOT/out - build one first (scripts/build-iso.sh) or pass a path"
fi
[[ -z $ISO || -r $ISO ]] || die "cannot read ISO: $ISO"

# --------------------------------------------------------------- the disk --

if [[ -n $DISK && ! -e $DISK ]]; then
    mkdir -p "$(dirname "$DISK")"
    log "creating $DISK ($DISK_SIZE)"
    qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null
fi

# ------------------------------------------------------------- the flags --

QEMU=(qemu-system-x86_64
      -name "UndraByte"
      -m "$RAM"
      -smp "$CPUS"
      -rtc base=utc
      -device virtio-balloon
      -object "rng-random,id=rng0,filename=/dev/urandom"
      -device "virtio-rng-pci,rng=rng0")

case $HOST_OS in
    Linux)
        if [[ -w /dev/kvm ]]; then
            QEMU+=(-enable-kvm -cpu host)
            ok "KVM acceleration enabled"
        else
            QEMU+=(-cpu max)
            warn "no writable /dev/kvm - falling back to TCG emulation. Expect it to be slow."
            warn "Add yourself to the 'kvm' group, or enable nested virtualisation on the outer hypervisor."
        fi
        ;;
    Darwin)
        # Hypervisor.framework. Present on every Intel Mac; absent on Apple
        # silicon for x86_64 guests, where this image can only be emulated.
        if [[ "$(sysctl -n kern.hv_support 2>/dev/null)" == 1 && "$(uname -m)" == x86_64 ]]; then
            QEMU+=(-accel hvf -cpu host)
            ok "HVF acceleration enabled (Hypervisor.framework)"
        else
            QEMU+=(-cpu max)
            warn "no usable HVF for an x86_64 guest - falling back to TCG emulation."
            [[ "$(uname -m)" == arm64 ]] && \
                warn "This is an Apple silicon Mac; an x86_64 image can only be emulated here, far too slowly for a desktop."
        fi
        ;;
    *)
        QEMU+=(-cpu max)
        warn "unknown host OS '$HOST_OS' - no acceleration flag applied."
        ;;
esac

if [[ $FIRMWARE == uefi ]]; then
    # "<code firmware>:<matching vars template>" - the vars file is copied per
    # VM so UEFI variables persist. Homebrew's QEMU uses its own naming.
    ovmf="" ovmf_vars_src=""
    for pair in \
        "/usr/share/edk2/x64/OVMF_CODE.4m.fd:/usr/share/edk2/x64/OVMF_VARS.4m.fd" \
        "/usr/share/edk2/x64/OVMF_CODE.fd:/usr/share/edk2/x64/OVMF_VARS.fd" \
        "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd:/usr/share/edk2-ovmf/x64/OVMF_VARS.fd" \
        "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd" \
        "/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd" \
        "/usr/local/share/qemu/edk2-x86_64-code.fd:/usr/local/share/qemu/edk2-i386-vars.fd" \
        "/opt/homebrew/share/qemu/edk2-x86_64-code.fd:/opt/homebrew/share/qemu/edk2-i386-vars.fd"
    do
        code="${pair%%:*}"
        if [[ -r $code ]]; then
            ovmf="$code"
            ovmf_vars_src="${pair#*:}"
            break
        fi
    done
    if [[ -n $ovmf ]]; then
        vars="${ROOT}/vm/UEFI_VARS.$(basename "$ovmf")"
        if [[ ! -e $vars ]]; then
            mkdir -p "$(dirname "$vars")"
            if [[ -r $ovmf_vars_src ]]; then
                cp "$ovmf_vars_src" "$vars"
            else
                warn "no UEFI variable template beside $ovmf; starting with a blank store"
                : > "$vars"
                dd if=/dev/zero of="$vars" bs=1m count=4 2>/dev/null
            fi
        fi
        QEMU+=(-drive "if=pflash,format=raw,readonly=on,file=$ovmf"
               -drive "if=pflash,format=raw,file=$vars")
        log "firmware: UEFI ($ovmf)"
    else
        warn "no UEFI firmware found; falling back to BIOS. Install 'edk2-ovmf' (Arch), 'ovmf' (Debian/Ubuntu/Fedora) or 'qemu' via Homebrew (macOS)."
        FIRMWARE=bios
    fi
fi
[[ $FIRMWARE == bios ]] && log "firmware: SeaBIOS"

# 3D: virtio-vga-gl needs a host GL context, which needs a display. Fall back
# cleanly on headless machines instead of failing with a cryptic QEMU error.
if [[ $HOST_OS == Darwin ]]; then
    # QEMU's cocoa display has no OpenGL passthrough, and there is no virglrenderer
    # on macOS, so 3D in the guest is off the table regardless of the flag.
    if [[ $GL == on ]]; then
        warn "--gl: QEMU on macOS has no GL passthrough (no virgl, cocoa has no gl=on). Ignoring."
    fi
    GL=off
    QEMU+=(-device virtio-vga -display "${QEMU_DISPLAY:-cocoa}")
    warn "graphics: software rendering (llvmpipe). Fine for the desktop and tooling; no Proton or Vulkan games."
else
    if [[ $GL == auto ]]; then
        if [[ -n ${DISPLAY-}${WAYLAND_DISPLAY-} ]]; then GL=on; else GL=off; fi
    fi
    if [[ $GL == on ]]; then
        QEMU+=(-device virtio-vga-gl -display "gtk,gl=on")
        log "graphics: virtio-vga-gl with host OpenGL (venus/virgl)"
    else
        QEMU+=(-device virtio-vga -display "${QEMU_DISPLAY:-gtk}")
        warn "graphics: no host GL context - the guest will use software rendering (llvmpipe)"
    fi
fi

QEMU+=(-device "virtio-net-pci,netdev=n0"
       -netdev "user,id=n0,hostfwd=tcp::${SSH_PORT}-:22")

QEMU+=(-device intel-hda -device hda-duplex)
QEMU+=(-device qemu-xhci -device usb-tablet -device usb-kbd)

# Guest agent + clipboard/resize channel.
QEMU+=(-device virtio-serial-pci
       -chardev "socket,path=${TMPDIR:-/tmp}/undrabyte-qga.sock,server=on,wait=off,id=qga0"
       -device "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0")

[[ -n $DISK ]] && QEMU+=(-drive "file=$DISK,if=virtio,format=qcow2,cache=writeback,discard=unmap")
if [[ -n $ISO ]]; then
    QEMU+=(-drive "file=$ISO,media=cdrom,readonly=on")
    [[ -z $DISK ]] && QEMU+=(-boot d)
fi

if [[ -n $SHARE ]]; then
    [[ -d $SHARE ]] || die "--share: not a directory: $SHARE"
    QEMU+=(-virtfs "local,path=$SHARE,mount_tag=hostshare,security_model=mapped-xattr,id=hostshare")
    log "sharing $SHARE as 9p tag 'hostshare'"
fi

# --- USB passthrough (a monitor-mode WiFi adapter reaching the guest) --------
#
# A virtio NIC is a paravirtual device; it has no radio, so it can never do
# monitor mode or injection. The only way to run aircrack-ng/hcxdumptool
# against your own AP from inside the VM is to hand the guest a real USB WiFi
# adapter. QEMU claims the device from the host for the life of the VM.

pick_wifi_adapter() {
    command -v lsusb &>/dev/null || die "--wifi needs lsusb (host package 'usbutils')"
    local -a lines=()
    # WiFi adapters are USB class-independent, so match on the vendor/product
    # text most known adapters advertise rather than a device class.
    mapfile -t lines < <(lsusb | grep -iE 'wl?an|wifi|wireless|802\.11|rtl8|ralink|atheros|mediatek|realtek.*adapter' || true)
    if (( ${#lines[@]} == 0 )); then
        warn "no obvious USB WiFi adapter in lsusb. Full device list:"
        lsusb >&2
        die "plug the adapter in, or name it explicitly with --usb VID:PID"
    fi
    if (( ${#lines[@]} == 1 )); then
        printf '%s\n' "${lines[0]}" | grep -oE '[0-9a-f]{4}:[0-9a-f]{4}' | head -1
        return
    fi
    printf '%sMore than one candidate adapter:%s\n' "$C_BOLD" "$C_RST" >&2
    local i
    for i in "${!lines[@]}"; do printf '  %d) %s\n' "$((i+1))" "${lines[i]}" >&2; done
    local choice
    read -rp "Pass which one through? [1-${#lines[@]}] " choice
    if ! [[ $choice =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#lines[@]} )); then
        die "not a listed choice: $choice"
    fi
    printf '%s\n' "${lines[choice-1]}" | grep -oE '[0-9a-f]{4}:[0-9a-f]{4}' | head -1
}

if (( ${#USB_IDS[@]} )); then
    warn "USB passthrough gives the GUEST exclusive control of the device; it disappears from the host until the VM stops."
    for id in "${USB_IDS[@]}"; do
        [[ $id == __pick_wifi__ ]] && id="$(pick_wifi_adapter)"
        [[ $id =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]] || die "--usb wants VID:PID (e.g. 0bda:8812), got: $id"
        QEMU+=(-device "usb-host,vendorid=0x${id%%:*},productid=0x${id##*:}")
        log "passing USB device $id through to the guest"
    done
    printf '%s    the adapter needs a Linux driver that supports monitor mode; see docs/WIFI-SECURITY.md%s\n' \
        "$C_DIM" "$C_RST"
fi

(( ${#EXTRA[@]} )) && QEMU+=("${EXTRA[@]}")

printf '\n%s%s%s\n\n' "$C_DIM" "${QEMU[*]}" "$C_RST"
exec "${QEMU[@]}"
