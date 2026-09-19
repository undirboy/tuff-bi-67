# Installing to a disk

Live booting is fine for a rescue or a demo, but nothing survives a reboot.
`undrabyte-install` puts UndraByte on a real (or virtual) disk.

## What it does

It runs the same sequence a careful person runs by hand from the Arch wiki:

1. Partition the disk (GPT; 1 GiB ESP for UEFI, or a 2 MiB BIOS boot partition)
2. Optionally LUKS2-encrypt the root partition
3. Format ext4, or btrfs with `@` and `@home` subvolumes and zstd compression
4. `pacstrap` the same package lists the ISO was built from
5. Generate `/etc/fstab` with `genfstab -U`
6. Configure the chroot: locale, timezone, hostname, initramfs, user, groups
7. Install and configure GRUB
8. Copy the UndraByte configuration and the `undrabyte-*` tools across

Nothing is hidden. Every destructive command is printed before it runs, and
`--dry-run` prints the entire plan — including the chroot script — without
touching anything.

## Use it

```bash
# See the plan first. Always.
sudo undrabyte-install --dry-run --disk /dev/vda

# Typical VM install
sudo undrabyte-install --disk /dev/vda --user you --hostname forge-vm

# Btrfs, swapfile, encrypted, XFCE, security tools only
sudo undrabyte-install --disk /dev/nvme0n1 --fs btrfs --swap 16G --encrypt \
                      --edition security --desktop xfce --user you
```

Options:

```
--disk DEV         target disk (prompted if omitted)
--user NAME        account to create (prompted if omitted)
--hostname NAME    default: undrabyte
--fs ext4|btrfs    default: ext4
--edition NAME     full, security, dev, gaming, minimal
--desktop NAME     kde, xfce, none
--swap SIZE        swapfile, e.g. 8G (default: none)
--timezone ZONE    default: detected from the network, else UTC
--encrypt          LUKS2 on the root partition
--archinstall      hand over to Arch's own guided installer instead
--dry-run          print everything, change nothing
--noconfirm        skip the final confirmation (scripted installs)
```

It asks you to type the disk path back before it erases anything.

## Afterwards

```bash
umount -R /mnt          # plus: cryptsetup close cryptroot, if you used --encrypt
reboot
```

Remove the installation medium as the machine restarts. Then:

```bash
undrabyte-vmcheck            # is the hypervisor integration healthy?
undrabyte-toolkit status     # what's enabled
sudo pacman -Syu            # you are on a rolling release now
```

## Prefer Arch's own installer?

```bash
sudo undrabyte-install --archinstall
```

You get `archinstall`'s guided menus. The UndraByte package sets are not
applied automatically that way — add them afterwards:

```bash
sudo pacman -S --needed - < /usr/local/share/undrabyte/packages/50-security.list
```

(That works because pacman ignores `#` comments and blank lines on stdin.)

## Dual-booting

`undrabyte-install` erases the whole target disk; it does not resize or share
one. To dual-boot, partition ahead of time with GParted, then install by hand
following the [Arch installation
guide](https://wiki.archlinux.org/title/Installation_guide) — the package
lists in `/usr/local/share/undrabyte/packages/` are the only UndraByte-specific
part, and `os-prober` will pick up the other system when you run
`grub-mkconfig`.

## Known limitations

- One disk, erased entirely — no dual-boot, no LVM, no RAID
- No Secure Boot signing: disable Secure Boot, or sign the bootloader yourself
  with `sbctl` afterwards
- Encrypted installs put `/boot` unencrypted on the ESP, which is the standard
  LUKS-on-root layout
