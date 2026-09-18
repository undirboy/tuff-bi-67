# Running on a small machine

The reference target for this page is a **dual-core Intel i5 MacBook Air with
8 GB of RAM** — and, by extension, any laptop of that class: 2 cores / 4
threads, 8 GB, integrated graphics, a small SSD.

## The honest verdict

| | |
|---|---|
| Security tooling in a VM | **yes** — this is what the machine is good for |
| Coding in a VM | **yes** — editors, compilers, Python/Go/Rust all fine |
| Desktop (XFCE) in a VM | **yes**, at 4 GB with zram |
| Desktop (KDE Plasma) in a VM | no — build XFCE |
| Steam / Proton / any 3D game | **no**, and no setting changes that |
| Building the full ISO on the machine itself | no — not enough disk |
| Building the `lite` ISO on the machine | yes, with ~15 GB free |

The gaming half of HexForge needs a GPU the guest can actually reach. macOS
hosts have no virgl/venus, an integrated Intel GPU has nothing to pass
through, and VirtualBox/VMware give you OpenGL but never Vulkan — which
Proton and DXVK require. That is a hardware and hypervisor limitation, not a
configuration one.

Everything else works well. A 4 GB guest running XFCE, nmap, Metasploit,
mitmproxy, Python and Neovim is a perfectly good security workstation.

## Build the `lite` edition

```bash
./scripts/check-host.sh                       # confirm the numbers first
make iso-lite                                 # = --edition lite --desktop xfce --vm-only
```

`lite` is ~130 packages and produces roughly a 2.5 GB ISO. Compared with
`full` it drops:

- the entire gaming stack (Steam, Proton, Wine, Gamescope, RetroArch, all of
  the 32-bit multilib libraries) — that alone is several GB
- Ghidra and Cutter, which are JVM/Qt applications that want 4 GB to
  themselves
- Docker, Podman, libvirt and `qemu-full` — nested containers and VMs on a
  dual-core host are not a good use of the cores
- VS Code, Chromium, GIMP, OBS
- bare-metal firmware blobs (`--vm-only`)

What it keeps: nmap, Metasploit, sqlmap, mitmproxy, Wireshark CLI, tcpdump,
john, hydra, impacket, radare2, binwalk, gobuster, ffuf, Tor/proxychains,
Scapy, and a full Python/C toolchain with Neovim, plus Firefox and KeePassXC
on the XFCE desktop. See [`packages/45-lite.list`](../packages/45-lite.list) —
adding anything back is one line.

### Where to build it

Building needs an Arch userland, so on a Mac that means Docker Desktop:

```bash
./scripts/build-iso.sh --docker --edition lite --desktop xfce --vm-only
```

Give Docker Desktop at least 4 GB of memory and make sure you have ~15 GB of
free disk. If the Air is short on space, build on another machine and copy the
ISO across — it is one file.

## Run it

### QEMU (recommended on Intel Macs)

```bash
brew install qemu
./scripts/run-vm.sh --disk vm/hexforge.qcow2 --size 30G
```

`run-vm.sh` detects macOS and uses **HVF** (Hypervisor.framework) for
acceleration, the **cocoa** display, and Homebrew's UEFI firmware. It also
sizes the guest from your host automatically — on an 8 GB dual-core machine
that comes out at **4 GB and 2 vCPUs**, which is what you want. Override with
`--ram` / `--cpus` if you disagree.

### UTM

A friendlier QEMU front end, free from the Mac App Store or
[mac.getutm.app](https://mac.getutm.app). Create an **Emulate → Other** VM,
then set: architecture x86_64, **4096 MB** memory, **2** CPUs, a 30 GB disk,
and attach the ISO. Leave hardware acceleration on (it uses HVF on Intel).

### VMware Fusion

Free for personal use and the smoothest of the GUI options on Intel Macs.
4 GB, 2 processors, UEFI firmware, 30 GB disk. `open-vm-tools` is already in
the image, so clipboard and resize work immediately.

### VirtualBox

Works, but it is the slowest of the three on modern macOS. Enable EFI, set the
graphics controller to VMSVGA with 128 MB, 4 GB RAM, 2 CPUs.

## Living inside 4 GB

Already done for you by the image:

- **zram** — 4 GB of zstd-compressed swap in RAM, configured in
  `/etc/systemd/zram-generator.conf`. This is the single biggest win at this
  size; it typically buys you 1.5–2× the usable memory.
- **XFCE** rather than Plasma: roughly 400 MB at idle instead of 1.2 GB.
- `vm.swappiness = 10` so the kernel prefers dropping cache over swapping.

Worth doing yourself:

```bash
# Check what is actually eating memory
btop

# Metasploit's console is the heaviest thing in the lite set (~700 MB).
# Run it only when you need it, and skip the database if you are not using it:
msfconsole -q -n

# Firefox with many tabs will outweigh everything else. about:config >
# browser.tabs.unloadOnLowMemory = true
```

Do not run a browser, Metasploit and a compile at the same time on a 4 GB
guest. It will work; it will not be pleasant.

## The lighter option: headless + SSH

On a dual-core host, the guest desktop is what costs you. Skipping it entirely
is a genuinely nicer workflow on this class of machine:

```bash
./scripts/build-iso.sh --docker --edition lite --desktop none --vm-only
./scripts/run-vm.sh --disk vm/hexforge.qcow2 --ram 3G --cpus 2 --ssh-port 2222
```

Then, from macOS Terminal (or iTerm, or VS Code's Remote-SSH):

```bash
ssh -p 2222 forge@localhost
```

You keep the Mac's own polished terminal and editor, the guest spends all of
its memory on tools instead of a compositor, and a 3 GB guest is plenty.
Enable `sshd` inside the guest first — it ships disabled on purpose:

```bash
sudo systemctl enable --now sshd
```

> Set a real password before doing that. A machine with `forge`/`forge` and an
> open SSH port is not yours for long.

## What to expect

On a 2015-era dual-core i5 with HVF acceleration and a 4 GB guest:

- Boot to XFCE desktop: 30–60 seconds from the live ISO, faster once installed
- `nmap -sV` across a /24 lab network: comparable to bare metal — network
  scanning is not CPU-bound
- `msfconsole` first start: 30–60 seconds
- Compiling a medium C project: roughly half the speed of the host, because
  you gave the guest half the cores
- Firefox: usable, not fast
- Anything 3D: software rendered, so single-digit frames per second

If that sounds acceptable, the machine is fine. If you need the gaming half of
HexForge, you need a different machine — see [GAMING.md](GAMING.md).
