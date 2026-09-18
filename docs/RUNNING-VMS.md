# Running HexForge in a virtual machine

HexForge is built to be a guest. The guest agents for QEMU/KVM, VirtualBox,
VMware and Hyper-V are all installed and enabled; whichever one matches gets
started at boot by `hexforge-live-setup.service`.

After booting, run **`hexforge-vmcheck`**. It reports the hypervisor, the
graphics driver, 3D acceleration, the guest agent and folder sharing, and
prints the host-side fix for anything that is wrong.

## Recommended resources

| Edition | vCPU | RAM | Disk |
|---|---|---|---|
| `minimal` / `dev` | 2 | 4 GB | 30 GB |
| `security` | 4 | 8 GB | 60 GB |
| `gaming` / `full` | 4–8 | 8–16 GB | 80 GB+ |

Live booting needs no disk, but nothing survives a reboot. Attach one and run
`hexforge-install` if you want to keep your work.

## QEMU / KVM (best support)

Use the wrapper — it gets the flags right:

```bash
./scripts/run-vm.sh --disk vm/hexforge.qcow2 --size 80G --ram 12G --cpus 6 --share ~/projects
```

What it sets up, and why:

| Flag | Reason |
|---|---|
| `-enable-kvm -cpu host` | without KVM you are emulating, which is 10–50× slower |
| `-device virtio-vga-gl -display gtk,gl=on` | virgl/venus 3D; without it you get llvmpipe |
| `-device virtio-net-pci` + user networking | fast NIC; `--ssh-port` forwards to `:22` |
| `-device virtio-serial` + `org.qemu.guest_agent.0` | lets the host query and gracefully shut down the guest |
| `-drive if=virtio,discard=unmap` | fast disk that returns free space to the host |
| OVMF pflash pair | UEFI boot with persistent NVRAM |

Mount a `--share` inside the guest:

```bash
sudo mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt
```

### virt-manager / libvirt

Same machine, clickable. The settings that matter:

- Chipset **Q35**, firmware **UEFI (OVMF)**
- CPU model: **host-passthrough**
- Video: **Virtio**, tick **3D acceleration**
- Display: **Spice**, with **OpenGL** enabled and a render node selected
- Add a **Channel** device, `org.qemu.guest_agent.0`
- Disk bus **VirtIO**, NIC model **virtio**

3D acceleration in virt-manager requires Spice + OpenGL *and* a virtio video
device. Miss either and `hexforge-vmcheck` will report llvmpipe.

## VirtualBox

Settings that matter:

- **System → Motherboard**: Enable EFI, 8 GB RAM, ICH9 chipset
- **System → Processor**: 4 CPUs, enable PAE/NX and VT-x/AMD-V nested paging
- **Display → Graphics Controller**: **VMSVGA**, 128 MB video memory,
  **Enable 3D Acceleration**
- **Storage**: SATA for the disk, attach the ISO to the optical drive
- **Shared Folders**: add one, tick *Auto-mount* (the guest utilities are
  already installed; mounts appear under `/media/sf_<name>`)

Guest additions are provided by the distribution's `virtualbox-guest-utils`
package — do **not** install the Oracle guest additions ISO over them.

VirtualBox gives you OpenGL but **no Vulkan**, so Steam/Proton and DXVK will
not work. Native Linux games and emulators are fine.

## VMware Workstation / Player / Fusion

- Firmware: UEFI
- Enable **Accelerate 3D graphics**, give it 2 GB of graphics memory
- Enable **Virtualize Intel VT-x/EPT** if you want nested KVM or Docker speed
- `open-vm-tools` is already installed; do not install VMware Tools manually

Shared folders appear under `/mnt/hgfs` once enabled on the host.

## Hyper-V

- **Generation 2** VM
- Disable **Secure Boot**, or the ISO will not boot (it is not signed with a
  Microsoft key)
- Enable **Enhanced Session Mode** on the host for clipboard and resize
- Give it a **Dynamic Memory** floor of at least 4 GB

Hyper-V provides no 3D acceleration for Linux guests. Expect a software
renderer, and use it for the security and development work rather than games.

## Proxmox VE

- BIOS: **OVMF (UEFI)**, add an EFI disk
- Machine: **q35**
- CPU: **host**
- Display: **VirtIO-GPU** (add `virgl` on the host for 3D)
- SCSI controller: **VirtIO SCSI single**, disk with **Discard** and **SSD emulation**
- Enable the **QEMU Guest Agent** option in Options → QEMU Guest Agent

## WSL2

WSL2 runs a Microsoft kernel, so a live ISO is not how you use it. If you want
the *userland*, import a rootfs instead:

```bash
# on an Arch host or in the archlinux container
sudo pacstrap -c rootfs $(./scripts/build-iso.sh --edition security --desktop none --list-packages)
sudo tar -C rootfs -czf hexforge-wsl.tar.gz .
# on Windows
wsl --import HexForge C:\WSL\HexForge hexforge-wsl.tar.gz
```

Systemd services, the live-setup unit and the bootloader are all irrelevant
there; the tools are not.

## Troubleshooting

**Black screen after the boot menu** — pick the *safe graphics / nomodeset*
entry, or give the VM a virtio-gpu or VMSVGA adapter.

**Desktop stuck at 1024×768, resize does nothing** — the guest agent is not
running. `hexforge-vmcheck` says which one is missing; usually the host is
missing the SPICE channel or the VirtualBox graphics controller is set to
VBoxVGA instead of VMSVGA.

**No clipboard between host and guest** — QEMU needs the SPICE vdagent
channel (use virt-manager's Spice display); VirtualBox needs
*Devices → Shared Clipboard → Bidirectional*.

**`hexforge-vmcheck` says llvmpipe** — there is no GPU acceleration. See the
per-hypervisor sections above, and [GAMING.md](GAMING.md) for what that costs
you.

**Extremely slow, fans at full speed** — KVM is not enabled. On Linux hosts,
add yourself to the `kvm` group; in a nested setup, enable nested
virtualisation on the outer hypervisor.

**Boot stops at `ERROR: device 'HEXFORGE_...' not found`** — the ISO was
copied wrong, or the virtual optical drive disconnected. Re-attach the ISO;
if you wrote it to USB, use `dd`/`cp` rather than a file copy onto a
filesystem.
