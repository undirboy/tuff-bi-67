# How the build works

UndraByte is an [archiso](https://gitlab.archlinux.org/archlinux/archiso)
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
   `/usr/local/share/undrabyte/`, so `undrabyte-install` and `undrabyte-toolkit`
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
   and pacman aborts the whole transaction. `NoExtract` does not help — the
   conflict check runs before extraction. The two ways out are to keep the
   path out of the overlay entirely, or to install it from a pacman hook in
   `airootfs/etc/pacman.d/hooks/`, which is what the branding hook does for
   `/usr/lib/os-release`. Files in the owning package's `backup` array (such
   as `/etc/pacman.conf`) are the exception pacman tolerates.
   `scripts/verify-packages.sh` checks the whole overlay against package file
   ownership in CI, so a new collision fails in seconds rather than at
   pacstrap.
2. It is why the live user is created by a boot-time service rather than by
   shipping `/etc/passwd` — see below.

| Path | Why |
|---|---|
| `usr/local/lib/undrabyte/os-release` | branding source, applied to `/usr/lib/os-release` by a pacman hook |
| `etc/pacman.d/hooks/` | the branding hook — the overlay cannot ship `/usr/lib/os-release` directly |
| `etc/undrabyte/live.conf` | live username, password, sudo policy |
| `usr/lib/undrabyte/live-setup.sh` | creates the live user, configures autologin, starts the right guest agent |
| `etc/systemd/system/*.target.wants/` | service enablement — archiso never runs `systemctl enable` |
| `etc/mkinitcpio.conf.d/archiso.conf` | the hooks that make a squashfs-on-ISO root bootable |
| `etc/sysctl.d/99-undrabyte.conf` | `vm.max_map_count` for Proton, `ptrace_scope=0` for debugging |
| `etc/security/limits.d/99-undrabyte.conf` | file descriptors for esync, realtime priority for audio |
| `etc/skel/` | shell config, MangoHud, Starship prompt |
| `usr/local/bin/undrabyte-*` | the tools described in the README |

## Why a runtime setup service instead of baked-in accounts

Upstream archiso ships `/etc/shadow` to unlock root. Shipping `/etc/passwd`
and `/etc/shadow` to add a *desktop* user is worse than it looks: the overlay
lands after pacstrap, so it would erase the service accounts (`sddm`,
`polkitd`, `usbmux`, …) that packages created during installation.

`undrabyte-live-setup.service` avoids that. It is gated on
`ConditionPathExists=/run/archiso`, so it runs only on live media, and it:

- creates the live user with `useradd`, adding only groups that actually exist
  in this edition;
- sets the password from `/etc/undrabyte/live.conf`;
- writes SDDM or LightDM autologin config for whichever is installed, unless
  `undrabyte.nodm=1` is on the kernel command line;
- detects the hypervisor with `systemd-detect-virt` and starts the matching
  guest agent.

An installed system never runs it — `undrabyte-install` configures a real
account instead.

## Where edition logic lives

Two places, deliberately mirrored:

- `scripts/lib/common.sh` → `edition_lists()`, used at **build** time.
- `/usr/local/bin/undrabyte-install` → `resolve_packages()`, used at **install**
  time, reading the manifests copied into the image.

If you add an edition, add it to both. `scripts/lint.sh` walks every
edition × desktop combination and fails if one resolves to an implausibly
small package set, which catches a missing manifest immediately.
