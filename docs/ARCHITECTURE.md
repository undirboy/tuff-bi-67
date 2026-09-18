# How the build works

HexForge is an [archiso](https://gitlab.archlinux.org/archlinux/archiso)
profile with a generated package list. Nothing here is magic; the value is in
the assembly.

## The pipeline

```
packages/*.list ─┐
                 ├─→ scripts/build-iso.sh ─→ build/profile/ ─→ mkarchiso ─→ out/*.iso
profile/ ────────┘        (staging)          (generated)
```

`scripts/build-iso.sh`:

1. **Resolves the package set.** `edition_lists()` in `scripts/lib/common.sh`
   maps an edition + desktop to a list of manifests; `resolve_packages()`
   strips comments, de-duplicates and sorts them.
2. **Stages a copy** of `profile/` into `build/profile/`. The source profile
   is never modified, so a build never dirties the working tree.
3. **Generates `packages.x86_64`** in the staged copy, with a header recording
   the flags it was built with.
4. **Wires up the display manager.** `display-manager.service`,
   `graphical.target.wants/` and `default.target` are symlinked to SDDM
   (KDE), LightDM (XFCE), or `multi-user.target` (headless). These are
   generated rather than committed because a dangling SDDM symlink on an XFCE
   image means no login screen.
5. **Copies the manifests and docs** into the image at
   `/usr/local/share/hexforge/`, so `hexforge-install` and `hexforge-toolkit`
   can read them at runtime.
6. **Appends the BlackArch repo** to the staged `pacman.conf` when asked, after
   checking the build host has the keyring.
7. **Runs `mkarchiso`**, which pacstraps the packages into a root filesystem,
   overlays `airootfs/`, builds an initramfs with the archiso hooks, squashes
   the result and wraps it in a hybrid ISO.

## The profile

```
profile/
  profiledef.sh          ISO metadata, boot modes, squashfs settings, file modes
  pacman.conf            repositories used *while building* (multilib enabled)
  grub/grub.cfg          UEFI boot menu
  syslinux/*.cfg         legacy BIOS boot menu
  airootfs/              laid over the root filesystem after pacstrap
```

`profiledef.sh` sets `bootmodes` to syslinux for BIOS and GRUB for UEFI.
systemd-boot is deliberately unused: both it and GRUB want to own
`EFI/BOOT/BOOTX64.EFI`, and GRUB is the more forgiving of the two across
OVMF, VirtualBox and VMware firmware.

## What lives in `airootfs/`

**`mkarchiso` copies this overlay into the work directory *before* it runs
`pacstrap`,** not after. That ordering matters twice over:

1. Any path the overlay ships that a package also owns is a **file conflict**,
   and pacman aborts the whole transaction. The build pacman.conf carries a
   `NoExtract` line for each such path; `scripts/verify-packages.sh` checks
   that list against the overlay in CI and fails if a new file needs one.
2. It is why the live user is created by a boot-time service rather than by
   shipping `/etc/passwd` — see below.

| Path | Why |
|---|---|
| `usr/lib/os-release` | branding (`ID=hexforge`, `ID_LIKE=arch`) |
| `etc/hexforge/live.conf` | live username, password, sudo policy |
| `usr/lib/hexforge/live-setup.sh` | creates the live user, configures autologin, starts the right guest agent |
| `etc/systemd/system/*.target.wants/` | service enablement — archiso never runs `systemctl enable` |
| `etc/mkinitcpio.conf.d/archiso.conf` | the hooks that make a squashfs-on-ISO root bootable |
| `etc/sysctl.d/99-hexforge.conf` | `vm.max_map_count` for Proton, `ptrace_scope=0` for debugging |
| `etc/security/limits.d/99-hexforge.conf` | file descriptors for esync, realtime priority for audio |
| `etc/skel/` | shell config, MangoHud, Starship prompt |
| `usr/local/bin/hexforge-*` | the tools described in the README |

## Why a runtime setup service instead of baked-in accounts

Upstream archiso ships `/etc/shadow` to unlock root. Shipping `/etc/passwd`
and `/etc/shadow` to add a *desktop* user is worse than it looks: the overlay
lands after pacstrap, so it would erase the service accounts (`sddm`,
`polkitd`, `usbmux`, …) that packages created during installation.

`hexforge-live-setup.service` avoids that. It is gated on
`ConditionPathExists=/run/archiso`, so it runs only on live media, and it:

- creates the live user with `useradd`, adding only groups that actually exist
  in this edition;
- sets the password from `/etc/hexforge/live.conf`;
- writes SDDM or LightDM autologin config for whichever is installed, unless
  `hexforge.nodm=1` is on the kernel command line;
- detects the hypervisor with `systemd-detect-virt` and starts the matching
  guest agent.

An installed system never runs it — `hexforge-install` configures a real
account instead.

## Where edition logic lives

Two places, deliberately mirrored:

- `scripts/lib/common.sh` → `edition_lists()`, used at **build** time.
- `/usr/local/bin/hexforge-install` → `resolve_packages()`, used at **install**
  time, reading the manifests copied into the image.

If you add an edition, add it to both. `scripts/lint.sh` walks every
edition × desktop combination and fails if one resolves to an implausibly
small package set, which catches a missing manifest immediately.
