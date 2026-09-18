# HexForge Linux

A buildable Linux distribution for the three things that usually need three
different machines: **security work**, **software development**, and **gaming** —
designed from the start to run inside a virtual machine.

HexForge is an Arch-based live ISO built with [archiso](https://gitlab.archlinux.org/archlinux/archiso).
This repository is the *recipe*, not the image: you build the ISO yourself, so
you know exactly what is in it and can change any of it.

```
git clone https://github.com/undirboy/tuff-bi-67 && cd tuff-bi-67
./scripts/lint.sh                 # sanity-check the profile
sudo ./scripts/build-iso.sh       # build (Arch host) …
./scripts/build-iso.sh --docker   # … or anywhere with Docker
./scripts/run-vm.sh               # boot it in QEMU/KVM
```

---

## What you get

| | |
|---|---|
| **Base** | Arch Linux (rolling), Linux mainline kernel, systemd, NetworkManager |
| **Desktop** | KDE Plasma (default) or XFCE, or headless |
| **Security** | nmap, Wireshark, Metasploit, aircrack-ng, hashcat, John, sqlmap, Ghidra, radare2, mitmproxy, bettercap, impacket, Burp-ready JVM — plus one command to add [BlackArch](https://blackarch.org)'s ~3000 tools |
| **Development** | gcc/clang/LLVM, Python, Go, Rust, Node, JDK, Neovim, VS Code, Docker, Podman, libvirt/QEMU for nested VMs |
| **Gaming** | Steam, Proton, Lutris, Wine, Gamescope, GameMode, MangoHud, RetroArch, PipeWire low-latency audio, full 32-bit multilib stack |
| **Virtualisation** | Guest agents for QEMU/KVM, VirtualBox, VMware and Hyper-V; virtio-gpu / virgl / venus 3D; clipboard, resize and folder sharing that work out of the box |

Live user: **`forge` / `forge`** (change it in `profile/airootfs/etc/hexforge/live.conf`
before building anything you hand to someone else).

## Editions

The ISO contents come from plain text manifests in [`packages/`](packages/), so
you can pick how much you want:

| Edition | Contents | Rough ISO size |
|---|---|---|
| `minimal` | base + desktop + VM guest tools | ~2 GB |
| `dev` | + toolchains, editors, containers | ~4 GB |
| `security` | + dev, + the security toolkit | ~6 GB |
| `gaming` | + Steam/Proton/Wine/emulation | ~5 GB |
| `full` *(default)* | everything above | ~8 GB |
| `--with-blackarch` | + four BlackArch groups | +4–6 GB |

```bash
make iso EDITION=security DESKTOP=xfce VM_ONLY=1
make packages EDITION=gaming          # see exactly what that resolves to
```

`--vm-only` drops bare-metal firmware blobs (~400 MB) from an image you will
only ever boot in a hypervisor.

## Running it

`scripts/run-vm.sh` wraps QEMU with settings that are correct rather than
default — KVM when available, UEFI via OVMF, virtio everywhere, and a host
OpenGL context so the desktop is not stuck on software rendering:

```bash
./scripts/run-vm.sh                                   # live boot the newest ISO
./scripts/run-vm.sh --disk vm/hexforge.qcow2 --size 80G   # with a disk to install onto
./scripts/run-vm.sh --share ~/projects --ram 12G --cpus 8
```

VirtualBox, VMware and Hyper-V are supported too — the per-hypervisor settings
that matter (and the ones that silently cost you 3D acceleration) are in
[docs/RUNNING-VMS.md](docs/RUNNING-VMS.md).

Inside the guest, `hexforge-vmcheck` tells you what is working and, for
anything that is not, what to change on the host.

## Installing to a disk

The live image carries `hexforge-install`: partition, format (ext4 or btrfs,
optionally LUKS2-encrypted), pacstrap the same package lists the ISO was built
from, configure the chroot, install GRUB. Every destructive step is printed
first, and `--dry-run` shows the whole plan without touching the disk.

```bash
sudo hexforge-install --dry-run --disk /dev/vda
sudo hexforge-install --disk /dev/vda --fs btrfs --swap 8G --user you
```

## On the ISO

| Command | What it does |
|---|---|
| `hexforge-welcome` | tour of the image |
| `hexforge-vmcheck` | hypervisor, 3D, guest-agent and sharing health, with fixes |
| `hexforge-game` | gaming stack check, launch options, `hexforge-game steam` |
| `hexforge-toolkit` | enable BlackArch, install tool groups, bootstrap AUR |
| `hexforge-install` | install to disk |

## Repository layout

```
packages/          package manifests, one per concern — the thing you edit most
profile/           the archiso profile
  profiledef.sh    ISO metadata, boot modes, filesystem type
  airootfs/        files laid over the live root filesystem
  grub/ syslinux/  UEFI and BIOS boot menus
scripts/
  build-iso.sh     stages the profile, generates packages.x86_64, runs mkarchiso
  run-vm.sh        QEMU launcher
  verify-packages.sh   checks every package name against the real repos
  lint.sh          shell, manifest and profile checks
docs/              per-topic documentation
```

`profile/packages.x86_64` is **generated**, not committed: the edition flags
decide what goes in it. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Before your first build

Package names drift in a rolling distribution. Run this first — it is quick
and saves you finding a typo 40 minutes into a build:

```bash
./scripts/verify-packages.sh --docker
```

Then see [docs/BUILDING.md](docs/BUILDING.md) for host requirements, build
times and disk space.

## Documentation

- [BUILDING.md](docs/BUILDING.md) — build the ISO, on Arch or anywhere else
- [RUNNING-VMS.md](docs/RUNNING-VMS.md) — QEMU, VirtualBox, VMware, Hyper-V, Proxmox
- [GAMING.md](docs/GAMING.md) — what runs in a VM, and GPU passthrough when it doesn't
- [SECURITY-TOOLKIT.md](docs/SECURITY-TOOLKIT.md) — what's included, BlackArch, building a lab
- [INSTALL.md](docs/INSTALL.md) — installing to a disk
- [CUSTOMISING.md](docs/CUSTOMISING.md) — your own packages, branding, defaults
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the build actually works
- [LEGAL.md](docs/LEGAL.md) — licensing, and the rules around the offensive tooling

## Use it legally

HexForge ships tools that intercept traffic, crack credentials and exploit
software. Those are legitimate professional tools, and using them against
systems you neither own nor have **written permission** to test is a criminal
offence in most of the world. Build a lab — [SECURITY-TOOLKIT.md](docs/SECURITY-TOOLKIT.md)
shows how to stand one up in an afternoon — and stay inside it.

## Licence

MIT for this build system; see [LICENSE](LICENSE). The software a built image
contains keeps its own licences.
