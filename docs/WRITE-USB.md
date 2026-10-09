# Put UndraByte on a USB stick — from Windows, macOS or Linux

UndraByte is a Linux live system. You don't *install* it on Windows or macOS;
you write the ISO to a USB stick and **boot your PC or Mac from that stick**.
The same stick boots both PCs (UEFI or legacy BIOS) and Intel Macs.

> A ≥ 8 GB USB stick. Writing it **erases the stick**.

## 1. Get the ISO

Download it from the release page. The small editions (lite, minimal) are a
single `.iso`. The large ones (dev, security, gaming, full) are split into
`…​.iso.part00`, `.part01`, … — download **every** part and `SHA256SUMS`, then
rejoin them into one `.iso` first:

- **Windows (PowerShell):** `cmd /c copy /b (undrabyte-*.iso.part00 + undrabyte-*.iso.part01 + …) undrabyte.iso`
- **macOS / Linux:** `cat undrabyte-*.iso.part* > undrabyte.iso` then `shasum -a 256 -c SHA256SUMS`

## 2. Write it to the stick

### Windows
- Easiest: **[balenaEtcher](https://etcher.balena.io/)** — pick the ISO, pick the
  stick, Flash. Or **[Rufus](https://rufus.ie/)**: select the ISO, leave
  partition scheme at the default, Start, accept "DD image" mode if asked.

### macOS
- Easiest: **balenaEtcher** (same as above).
- Or Terminal:
  ```bash
  diskutil list                      # find your stick, e.g. /dev/disk4
  diskutil unmountDisk /dev/diskN
  sudo dd if=undrabyte.iso of=/dev/rdiskN bs=4m   # note the 'r' in rdiskN (faster)
  diskutil eject /dev/diskN
  ```
  Double-check `diskN` — the wrong number overwrites the wrong drive.

### Linux
```bash
sudo dd if=undrabyte.iso of=/dev/sdX bs=4M conv=fsync status=progress   # sdX = the stick
```

## 3. Boot from it

- **Windows PC:** reboot and tap the boot-menu key (often **F12**, F10, F9,
  Esc, or Del) and choose the USB stick. If it won't appear, disable
  **Secure Boot** in the BIOS/UEFI (UndraByte is not signed with a Microsoft
  key). UEFI and legacy BIOS are both supported.
- **Intel Mac:** power on holding **⌥ Option (Alt)** until the boot picker
  appears, then choose **EFI Boot**. (Apple-Silicon M1/M2/… Macs cannot boot a
  generic x86-64 Linux ISO — use a VM such as UTM instead; see
  [RUNNING-VMS.md](RUNNING-VMS.md).)

## 4. If it won't boot

See the troubleshooting section of [RUNNING-VMS.md](RUNNING-VMS.md). In short:
every boot entry now finds the medium by scanning for the squashfs file (not
just the disc label), and the menu's **safe graphics / nomodeset** and
**copy to RAM** entries handle most stubborn machines. To keep your changes
between boots, use the **persistent** boot entry after running
`undrabyte-persist` (see the tool's help).
