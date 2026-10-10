# Secure Boot (with your own keys)

Secure Boot lets the firmware refuse to run a bootloader or kernel it can't
verify. UndraByte supports it the way you can actually use on your own
hardware: **your own keys**, generated on your machine, enrolled once. Secure
Boot stays *on*, verifying a chain you control — no vendor shim, no third party.

UndraByte does not ship a Microsoft-signed shim. That needs a paid signature
and a release process that doesn't fit a reproducible, self-built ISO. Your own
keys are just as secure for a machine you own, and often *more* trustworthy.

## One-time setup

1. **Put the firmware into Setup Mode.** Reboot into your BIOS/UEFI setup and
   clear (or delete) the existing Secure Boot keys. The exact wording varies —
   look for "Erase all Secure Boot keys", "Clear PK", or an "Custom / Setup
   mode" option. Save and exit.
2. **Boot UndraByte (installed system) and run:**
   ```
   sudo undrabyte-secureboot setup
   ```
   This creates your keys, enrolls them (keeping Microsoft's keys too, so
   discrete-GPU option ROMs and some firmware still initialise), signs the
   bootloader and kernels, and installs a pacman hook so future kernels are
   signed automatically.
3. **Re-enable Secure Boot** in firmware, and reboot.

Check it any time:

```
undrabyte-secureboot status     # Secure Boot + Setup Mode + sbctl state
undrabyte-secureboot verify     # what is signed / unsigned
sudo undrabyte-secureboot sign  # (re)sign after a manual kernel/bootloader change
```

## Notes

- This applies to an **installed** system. The live ISO isn't signed; disable
  Secure Boot to boot the installer, then enroll your keys afterward.
- It's UEFI-only. On a legacy-BIOS machine Secure Boot doesn't apply, and the
  tool says so.
- The automatic pacman hook means a kernel upgrade never leaves you with an
  unsigned, unbootable image. If you ever add a bootloader by hand, run
  `sudo undrabyte-secureboot sign` once.
- Keeping Microsoft's keys enrolled (`sbctl enroll-keys -m`) is deliberate:
  without them, some firmware and add-in GPUs refuse to start.
