#!/usr/bin/env bash
#
# Can this machine build and run HexForge?
#
# Run it on your own computer - not inside a HexForge guest - and it will tell
# you what works, what does not, and which editions your hardware can
# actually carry.
#
#   ./scripts/check-host.sh
#
# Read-only: it inspects, it never changes anything.

set -uo pipefail

_self="${BASH_SOURCE[0]}"
[[ -L $_self ]] && _self="$(readlink "$_self")"
# shellcheck source=scripts/lib/common.sh
source "$(cd -- "$(dirname -- "$_self")" && pwd)/lib/common.sh"

YES=$'\033[32myes\033[0m'
NO=$'\033[31mno\033[0m'
MEH=$'\033[33m~\033[0m'

blockers=()
warnings=()
host_cpus=0

row()   { printf '  %-26s %s\n' "$1" "${2-}"; }
sect()  { printf '\n%s%s%s\n' "$C_BOLD" "$1" "$C_RST"; }
note()  { printf '    %s%s%s\n' "$C_DIM" "$1" "$C_RST"; }
block() { blockers+=("$1"); }
warn_() { warnings+=("$1"); }

have() { command -v "$1" &>/dev/null; }

OS="$(uname -s)"

# ------------------------------------------------------------------ host --

sect "Host"
case $OS in
    Linux)
        distro="$( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || echo Linux)"
        row "operating system" "$distro"
        row "kernel" "$(uname -r)"
        ;;
    Darwin)
        row "operating system" "macOS $(sw_vers -productVersion 2>/dev/null)"
        row "architecture" "$(uname -m)"
        ;;
    *)
        row "operating system" "$OS"
        warn_ "This script understands Linux and macOS. On Windows, run it inside WSL2 - or see the Windows section printed at the end."
        ;;
esac

if [[ $OS == Linux ]] && have systemd-detect-virt; then
    v="$(systemd-detect-virt 2>/dev/null || echo none)"
    if [[ $v != none ]]; then
        row "already virtualised" "$v"
        note "You are inside a VM. Running HexForge here means nested virtualisation,"
        note "which needs to be enabled on the outer hypervisor to be usable."
    fi
fi

# ------------------------------------------------------------------- cpu --

sect "CPU"
case $OS in
    Linux)
        cpu="$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo)"
        cores="$(nproc)"; host_cpus=$cores
        row "model" "${cpu:-unknown}"
        row "logical cpus" "$cores"

        if grep -qE '^flags.*\b(vmx|svm)\b' /proc/cpuinfo; then
            row "VT-x / AMD-V" "$YES"
        else
            row "VT-x / AMD-V" "$NO"
            block "No hardware virtualisation extensions visible. Enable VT-x (Intel) or AMD-V/SVM (AMD) in your BIOS/UEFI setup - it is usually off by default on prebuilt PCs. Without it everything is emulated, which is 10-50x slower."
        fi

        if [[ -e /dev/kvm ]]; then
            if [[ -w /dev/kvm ]]; then
                row "/dev/kvm" "$YES (writable)"
            else
                row "/dev/kvm" "$MEH exists, not writable by you"
                warn_ "Add yourself to the kvm group so QEMU can use hardware acceleration: sudo usermod -aG kvm \$USER  (then log out and back in)."
            fi
        else
            row "/dev/kvm" "$NO"
            warn_ "The KVM kernel module is not loaded. On most distros: sudo modprobe kvm_intel  (or kvm_amd). VirtualBox and VMware do not need it."
        fi

        for m in kvm_intel kvm_amd; do
            n="/sys/module/$m/parameters/nested"
            [[ -r $n ]] && row "nested virt ($m)" "$(<"$n")"
        done

        (( cores < 2 )) && block "Only $cores logical CPU. Give a guest at least 2."
        (( cores >= 2 && cores <= 4 )) && note "Few cores: use the lite edition and give the guest 2 vCPUs."
        ;;
    Darwin)
        host_cpus="$(sysctl -n hw.logicalcpu)"
        row "model" "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple silicon")"
        row "logical cpus" "$host_cpus"
        if [[ "$(uname -m)" == arm64 ]]; then
            row "architecture" "$MEH Apple silicon (arm64)"
            block "HexForge is an x86_64 image. On an M-series Mac it can only run under full emulation (UTM/QEMU with TCG), which is far too slow for a desktop. Use an x86_64 machine, or build an aarch64 variant."
        else
            row "architecture" "x86_64 (Intel Mac)"
            if [[ "$(sysctl -n kern.hv_support 2>/dev/null)" == 1 ]]; then
                row "Hypervisor.framework" "$YES"
            else
                row "Hypervisor.framework" "$NO"
                block "kern.hv_support is 0: this Mac cannot accelerate VMs. Everything would be emulated."
            fi
            note "macOS hosts have no virgl/venus, so guest graphics are software-rendered."
            note "That is fine for the tooling and the desktop; it rules out Proton and Vulkan games."
            (( host_cpus <= 4 )) && note "Dual-core Mac: the lite edition with 2 vCPUs is the one to build."
        fi
        ;;
esac

# ---------------------------------------------------------------- memory --

sect "Memory"
case $OS in
    Linux) mem_kb="$(awk '/MemTotal/{print $2}' /proc/meminfo)" ;;
    Darwin) mem_kb=$(( $(sysctl -n hw.memsize) / 1024 )) ;;
    *) mem_kb=0 ;;
esac
mem_gb=$(( mem_kb / 1024 / 1024 ))
row "total RAM" "${mem_gb} GB"

if   (( mem_gb < 6 ));  then block "${mem_gb} GB of RAM. A guest needs 4 GB and the host needs about 4 GB of its own, so 8 GB is the realistic floor."
elif (( mem_gb < 10 )); then warn_ "${mem_gb} GB is enough for the minimal or dev edition with 4 GB given to the guest. The gaming and full editions want more."
elif (( mem_gb < 16 )); then note "Comfortable for the security edition (8 GB guest)."
else                         note "Enough for any edition, including 16 GB guests."
fi

# ------------------------------------------------------------------ disk --

sect "Disk"
avail_kb="$(df -Pk . | awk 'NR==2 {print $4}')"
avail_gb=$(( avail_kb / 1024 / 1024 ))
row "free here ($(pwd | head -c 40))" "${avail_gb} GB"

if   (( avail_gb < 30 )); then warn_ "${avail_gb} GB free. Building a full ISO needs ~25 GB of scratch plus the image itself; running a VM wants 30-80 GB more. Building a minimal --vm-only image needs far less."
elif (( avail_gb < 60 )); then note "Enough to build a trimmed image and run a small guest."
else                           note "Enough to build and run anything here."
fi

# -------------------------------------------------------------- graphics --

sect "Graphics"
if [[ $OS == Linux ]]; then
    drv=""
    for d in /sys/class/drm/card*/device/driver; do
        [[ -e $d ]] && { drv="$(basename "$(readlink -f "$d")")"; break; }
    done
    row "kernel driver" "${drv:-none detected}"

    if [[ -n ${DISPLAY-}${WAYLAND_DISPLAY-} ]]; then
        row "graphical session" "$YES (${WAYLAND_DISPLAY:+wayland}${DISPLAY:+${WAYLAND_DISPLAY:+ + }x11})"
    else
        row "graphical session" "$NO"
        warn_ "No DISPLAY or WAYLAND_DISPLAY. QEMU's GL passthrough needs a real desktop session on the host, so the guest would fall back to software rendering. Fine over SSH for headless work, not for the desktop or games."
    fi

    if have vulkaninfo; then
        gpu="$(vulkaninfo --summary 2>/dev/null | awk -F'= ' '/deviceName/{print $2; exit}')"
        row "host Vulkan" "${gpu:-none}"
        [[ -z $gpu ]] && warn_ "No Vulkan on the host, so the guest cannot get Vulkan through venus either - that rules out Steam/Proton in a VM."
    else
        row "host Vulkan" "$MEH vulkaninfo not installed (vulkan-tools)"
    fi

    case $drv in
        nvidia) note "NVIDIA proprietary driver: virgl/venus support is weaker than on Mesa. GPU passthrough is the reliable path for games." ;;
        amdgpu|i915|xe) note "Mesa driver: good virgl/venus support for accelerated VM graphics." ;;
    esac
fi
[[ $OS == Darwin ]] && row "3D in guests" "$MEH no virgl/venus; expect software rendering"

# ---------------------------------------------------------- hypervisors --

sect "Hypervisors and tools"
found=0
check_tool() {
    if have "$1"; then row "$2" "$YES  $($1 --version 2>/dev/null | head -1 | cut -c1-40)"; found=1
    else row "$2" "$NO"; fi
}
check_tool qemu-system-x86_64 "qemu (recommended)"
check_tool virt-manager       "virt-manager"
check_tool VBoxManage         "virtualbox"
check_tool vmrun              "vmware"
check_tool docker             "docker (for --docker builds)"
check_tool podman             "podman"
if have mkarchiso; then row "archiso (native build)" "$YES"; else row "archiso (native build)" "$NO"; fi

(( found )) || block "No hypervisor found. Install one: qemu + libvirt + virt-manager on Linux, or VirtualBox / VMware on any host."

if [[ $OS == Linux ]]; then
    ovmf=""
    for c in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2/x64/OVMF_CODE.fd \
             /usr/share/edk2-ovmf/x64/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE_4M.fd \
             /usr/share/OVMF/OVMF_CODE.fd; do
        [[ -r $c ]] && { ovmf=$c; break; }
    done
    if [[ -n $ovmf ]]; then
        row "UEFI firmware (OVMF)" "$YES"
    else
        row "UEFI firmware (OVMF)" "$NO"
        warn_ "No OVMF firmware found, so run-vm.sh will fall back to BIOS boot. Install 'edk2-ovmf' (Arch) or 'ovmf' (Debian/Ubuntu/Fedora) for UEFI."
    fi
fi

# ---------------------------------------------------------------- build --

sect "Building the ISO here"
if have mkarchiso && [[ $OS == Linux ]]; then
    row "native build" "$YES  sudo ./scripts/build-iso.sh"
elif have docker || have podman; then
    row "container build" "$YES  ./scripts/build-iso.sh --docker"
    have docker || note "You have podman, not docker. See docs/BUILDING.md for the podman command."
else
    row "build" "$NO"
    warn_ "Neither archiso nor a container runtime. Install docker (or podman), or build on an Arch machine."
fi

# -------------------------------------------------------------- verdict --

printf '\n%s%s%s\n' "$C_BOLD" "Verdict" "$C_RST"

if (( ${#blockers[@]} )); then
    printf '\n%sBlockers%s\n' "$C_RED" "$C_RST"
    for b in "${blockers[@]}"; do printf '  - %s\n' "$b"; done
fi
if (( ${#warnings[@]} )); then
    printf '\n%sWorth fixing%s\n' "$C_YEL" "$C_RST"
    for w in "${warnings[@]}"; do printf '  - %s\n' "$w"; done
fi

printf '\n'
if (( ${#blockers[@]} == 0 )); then
    printf '%sThis machine can run HexForge virtually.%s\n\n' "$C_GRN" "$C_RST"
    desktop=kde
    if   (( mem_gb >= 16 && host_cpus >= 8 )); then rec="full"
    elif (( mem_gb >= 12 && host_cpus >= 6 )); then rec="security"
    elif (( mem_gb >= 10 && host_cpus >= 4 )); then rec="dev"; desktop=xfce
    else                                            rec="lite"; desktop=xfce
    fi
    guest_ram=$(( mem_gb / 2 )); (( guest_ram > 8 )) && guest_ram=8
    (( guest_ram < 4 )) && guest_ram=4
    guest_cpus=$(( host_cpus / 2 )); (( guest_cpus < 2 )) && guest_cpus=2
    (( host_cpus < 2 )) && host_cpus=2
    printf 'Suggested first build for %s GB of RAM:\n' "$mem_gb"
    printf '  %s./scripts/build-iso.sh --edition %s --desktop %s --vm-only%s\n' \
        "$C_DIM" "$rec" "$desktop" "$C_RST"
    printf '  %s./scripts/run-vm.sh --ram %sG --cpus %s%s\n' "$C_DIM" "$guest_ram" "$guest_cpus" "$C_RST"
    if [[ $rec == lite ]]; then
        printf '\n%sThe lite edition drops the gaming stack, Ghidra and the container\ntooling so a 2-vCPU / 4 GB guest stays usable. See docs/LOW-SPEC.md.%s\n' \
            "$C_DIM" "$C_RST"
    fi
else
    printf '%sFix the blockers above first.%s\n' "$C_RED" "$C_RST"
fi

if [[ $OS != Linux && $OS != Darwin ]]; then
    cat <<'EOF'

On Windows, check by hand:
  - Task Manager > Performance > CPU: "Virtualization: Enabled"
  - systeminfo | findstr /i "hyper-v virtualization memory"
  - Use VirtualBox, VMware Workstation, or Hyper-V (Gen 2, Secure Boot OFF)
  - Build the ISO under WSL2 with Docker, or on an Arch machine
EOF
fi

exit $(( ${#blockers[@]} > 0 ))
