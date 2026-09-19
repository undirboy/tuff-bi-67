# Gaming

## The honest summary

A virtual machine does not have a GPU unless you give it one. That single fact
decides what will and will not run:

| Setup | OpenGL | Vulkan | What actually plays |
|---|---|---|---|
| No 3D (default Hyper-V, plain QEMU) | software | no | 2D games, emulators up to ~PS1, RetroArch software cores |
| VirtualBox 3D (VMSVGA) | yes | **no** | native Linux OpenGL titles, most emulators |
| QEMU virtio-gpu + virgl/venus | yes | yes (venus) | native Linux titles, most emulators, some Proton titles |
| **GPU passthrough (VFIO)** | native | native | everything, at near-bare-metal speed |
| Bare metal | native | native | everything |

Steam, Proton and DXVK need **Vulkan**. If `hexforge-game check` reports no
Vulkan device, Proton titles will not launch, no matter how much RAM you give
the VM.

## Check the stack

```bash
hexforge-game check      # drivers, Vulkan devices, gamemode, limits
hexforge-game tips       # launch options and VM advice
hexforge-vmcheck         # the host-side settings behind any of this
```

## Launching games

```bash
hexforge-game steam           # Steam with gamemode + MangoHud
hexforge-game run ./mygame    # anything else, same wrappers
```

Per-title Steam launch options:

```
gamemoderun mangohud %command%                  # the usual
RADV_PERFTEST=gpl gamemoderun %command%         # cuts shader-compilation stutter on AMD
SDL_VIDEODRIVER=x11 %command%                   # older titles that hate Wayland
PROTON_ENABLE_NVAPI=1 %command%                 # DLSS on NVIDIA passthrough
```

MangoHud toggles with **Right Shift + F12**; the overlay is configured in
`~/.config/mangohud/MangoHud.conf`.

## Epic, GOG and stores other than Steam

Steam is the only store with a native Linux client, and it is baked in. Epic,
GOG and Amazon do not ship one, so they run through community launchers:

- **Heroic** — a GUI for Epic + GOG + Amazon; installs and runs their games
  through Proton/Wine, the same way Steam does.
- **Legendary** — the Epic launcher as a command-line tool; scriptable and
  fine over SSH.

Both are AUR-only, so they are not in the ISO (an AUR build cannot be part of
a reproducible image). `hexforge-game` installs them on demand:

```bash
hexforge-game epic          # launch Heroic, or install it on first use
hexforge-game legendary     # the Epic CLI
```

Because these run Epic/GOG titles through Proton or Wine, everything below
about VM graphics — Vulkan, virtio-gpu, passthrough — applies to them exactly
as it does to Steam.

## Getting 3D in QEMU

```bash
./scripts/run-vm.sh --gl --ram 12G --cpus 6
```

which is shorthand for `-device virtio-vga-gl -display gtk,gl=on`. The host
needs a working GL context — that means an X11 or Wayland session, not SSH.
`run-vm.sh` detects this and falls back rather than dying with a QEMU error.

For **Vulkan** in the guest (venus), the host needs a reasonably recent
Mesa and QEMU built with virglrenderer + venus support, and the guest needs
`vulkan-virtio` — which HexForge installs. Verify with `vulkaninfo --summary`
inside the guest.

## GPU passthrough (VFIO) — the real answer

This is the only way to get genuine gaming performance out of a VM. It
requires:

1. **IOMMU** — `intel_iommu=on` or `amd_iommu=on` on the *host* kernel command
   line, and VT-d/AMD-Vi enabled in host firmware.
2. **A GPU the host can give up** — either a second GPU, or an iGPU for the
   host and a discrete card for the guest.
3. **The GPU alone in its IOMMU group** — check with:
   ```bash
   for g in /sys/kernel/iommu_groups/*/devices/*; do
       echo "group ${g%%/devices/*}: $(lspci -nns "${g##*/}")"
   done | sort -V
   ```
   If other devices share the group, they have to be passed through too.
4. **Binding it to vfio-pci at host boot**, before the host driver claims it:
   ```
   # /etc/modprobe.d/vfio.conf on the HOST
   options vfio-pci ids=10de:2484,10de:228b
   softdep nvidia pre: vfio-pci
   ```
5. **Adding the device to the VM** — in virt-manager, *Add Hardware → PCI Host
   Device*; in raw QEMU, `-device vfio-pci,host=01:00.0,multifunction=on`.

Useful extras once it works:

- **Looking Glass** for low-latency display without a second monitor
- **`hugepages`** for the guest's RAM, to reduce memory-access overhead
- **CPU pinning** (`<cputune>` in libvirt) so guest vCPUs get dedicated cores
- Pass the GPU's **HDMI audio function** through as well, or you get no sound

Passthrough is a host-side configuration exercise; HexForge is ready for it
the moment the card appears in the guest.

## Emulation

RetroArch is installed with the XMB assets. Cores are downloaded from within
RetroArch (*Online Updater → Core Downloader*) rather than shipped, because
core licensing varies and the set changes constantly.

Everything up to PS1/N64-era emulates comfortably on virtio-gpu 3D.
GameCube/PS2 and later want passthrough or bare metal.

## Anti-cheat

Kernel-level anti-cheat (Vanguard, most BattlEye and EAC titles in their
kernel modes) does not run on Linux, and detects virtualisation besides.
No configuration on this image changes that. Check
[ProtonDB](https://www.protondb.com/) before buying a multiplayer title.

## Tuning

Already applied by the image:

- `vm.max_map_count = 2147483642` — Proton/DXVK map a lot of small regions
- `nofile = 1048576` — esync needs the file descriptors
- `@audio` realtime priority and unlimited memlock — PipeWire low-latency
- GameMode — CPU governor to performance while a game runs

Worth doing yourself on an installed system:

```bash
sudo pacman -S linux-zen        # lower-latency scheduler tuning
sudo systemctl enable --now gamemoded
hexforge-toolkit aur            # protonup-qt (Proton-GE), goverlay, heroic
```
