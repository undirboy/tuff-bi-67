# Download UndraByte

Every edition is published as a GitHub Release you can download directly from
GitHub's CDN — no login, no account, resumable. Pick the one that fits, or use
the one-command helper below to download, verify and set it up for you.

## The easy way — one command

The helper downloads the edition you pick, rejoins split images, verifies the
checksum, and can write it straight to a USB stick or boot it in a VM:

```bash
curl -fsSLO https://raw.githubusercontent.com/undirboy/tuff-bi-67/main/scripts/get-undrabyte.sh
bash get-undrabyte.sh                       # pick an edition, download + verify
```

More ways to run it:

```bash
# a specific edition, into a folder
bash get-undrabyte.sh --edition security --dir ~/isos

# download, verify, then write to a USB stick (ERASES the stick)
sudo bash get-undrabyte.sh --edition lite --write /dev/sdX

# download, verify, then boot it in a throwaway QEMU VM
bash get-undrabyte.sh --edition minimal --vm

# just print the direct links, download nothing
bash get-undrabyte.sh --edition full --links
```

It needs only `curl` (or `wget`) and the usual coreutils, so it runs on a fresh
machine. Writing to USB needs `sudo`; the VM option needs `qemu`.

## Editions

| Edition | Best for | Size | Download |
|---|---|---|---|
| **minimal** | smallest bootable base + desktop | ~1.5 GB | [⬇ release](https://github.com/undirboy/tuff-bi-67/releases/tag/iso-minimal) |
| **lite** | small machines / a quick try (the default) | ~2 GB | [⬇ release](https://github.com/undirboy/tuff-bi-67/releases/tag/iso-latest) |
| **server** | headless self-hosting (no desktop) | ~2.5 GB | [⬇ release](https://github.com/undirboy/tuff-bi-67/releases/tag/iso-server) |
| **dev** | coding: toolchains, editors, containers | ~4 GB | [⬇ release](https://github.com/undirboy/tuff-bi-67/releases/tag/iso-dev) |
| **creator** | video / audio / image / 3D / streaming | ~6 GB | [⬇ release](https://github.com/undirboy/tuff-bi-67/releases/tag/iso-creator) |
| **security** | the full security toolkit + dev | ~6 GB | [⬇ release](https://github.com/undirboy/tuff-bi-67/releases/tag/iso-security) |
| **gaming** | Steam / Proton / Wine / emulation | ~5 GB | [⬇ release](https://github.com/undirboy/tuff-bi-67/releases/tag/iso-gaming) |
| **full** | everything above | ~9 GB | [⬇ release](https://github.com/undirboy/tuff-bi-67/releases/tag/iso-full) |

Not sure? **lite** boots fast and runs the security and coding tooling; pick
**full** if you want everything and have the disk.

## Downloading by hand

Each release page lists its files and a `SHA256SUMS`. Small editions are a
single `.iso`; big ones are split into `undrabyte-...-x86_64.iso.part00`,
`.part01`, … (GitHub caps a single file at 2 GiB). For a split image, download
**all** parts and `SHA256SUMS`, then rejoin and verify:

**Linux / macOS**
```bash
cat undrabyte-*-x86_64.iso.part* > undrabyte-x86_64.iso
sha256sum -c SHA256SUMS      # expect: …iso: OK  (and each part: OK)
```

**Windows (PowerShell)**
```powershell
cmd /c copy /b (undrabyte-*-x86_64.iso.part00 + undrabyte-*-x86_64.iso.part01 + ...) undrabyte-x86_64.iso
```

If the release has a `SHA256SUMS.asc` and `undrabyte-signing-key.asc`, you can
also verify the publisher's signature:

```bash
gpg --import undrabyte-signing-key.asc
gpg --verify SHA256SUMS.asc SHA256SUMS
```

## Setting it up

- **USB stick (real hardware):** write the `.iso` to a stick and boot it. The
  helper does this with `--write /dev/sdX`; to do it by hand, see
  [WRITE-USB.md](WRITE-USB.md) — it covers Windows (Rufus), macOS (incl. Intel
  Mac Option-boot) and Linux (`dd`), with the boot keys for each.
- **Virtual machine:** point UTM, QEMU, VirtualBox or VMware at the `.iso`. See
  [RUNNING-VMS.md](RUNNING-VMS.md) for per-hypervisor settings. The helper's
  `--vm` option boots it in QEMU for a quick look.
- **Install to disk:** boot the live image and run `undrabyte-install`
  (guided), or use the Control Center's *Install to disk* button. See
  [INSTALL.md](INSTALL.md).

Once booted, run `undrabyte` for the launcher, or `undrabyte-control` for the
graphical Control Center.
