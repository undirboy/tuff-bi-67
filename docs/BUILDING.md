# Building the ISO

## What you need

| | |
|---|---|
| Host OS | Arch Linux (or any distro + Docker, see below) |
| Packages | `archiso` (pulls in `arch-install-scripts`, `squashfs-tools`, `libisoburn`) |
| Privileges | root — `mkarchiso` mounts loop devices and chroots |
| Disk | 25 GB free for a `full` build, 40 GB with `--with-blackarch` |
| Network | the whole package set is downloaded; `full` is roughly 6–8 GB |
| Time | 20–60 min on a warm mirror, longer on first build |

## On Arch

```bash
sudo pacman -S archiso
git clone https://github.com/undirboy/tuff-bi-67 && cd tuff-bi-67

./scripts/verify-packages.sh      # check names resolve before committing an hour
sudo ./scripts/build-iso.sh
```

The ISO lands in `out/hexforge-<version>-x86_64.iso`.

## On anything else (Docker)

`mkarchiso` needs an Arch userland and loop devices, so the container must be
privileged. Everything else is handled for you:

```bash
./scripts/build-iso.sh --docker --edition security
```

This runs `archlinux:latest`, installs `archiso` inside it, bind-mounts the
repository at `/repo`, and writes the ISO to `out/` on the host.

> Podman works with `--privileged` too, but `scripts/build-iso.sh --docker`
> calls `docker` by name. Either alias it, or run the inner command yourself:
> ```bash
> podman run --rm --privileged -v "$PWD:/repo" -w /repo archlinux:latest \
>   bash -c 'pacman -Sy --noconfirm archiso && ./scripts/build-iso.sh --in-container'
> ```

## Options

```
--edition full|security|dev|gaming|minimal    which package manifests to include
--desktop kde|xfce|none                       desktop environment
--vm-only                                     drop bare-metal firmware (~400 MB)
--with-blackarch                              add the BlackArch repo + 4 groups
--with-nvidia                                 add the proprietary NVIDIA driver
--out DIR / --work DIR                        where output and scratch go
--keep-work                                   keep work/ for debugging
--list-packages                               print the resolved set and exit
--docker                                      build in a container
```

`make` wraps the common combinations:

```bash
make iso                                  # full / KDE
make iso EDITION=security DESKTOP=xfce
make iso-vm                               # trimmed, VM-only
make iso DOCKER=1 BLACKARCH=1
make packages EDITION=gaming              # just show me the package list
```

## `--with-blackarch` needs a keyring on the build host

BlackArch packages are signed by a key pacman does not know yet. Install the
keyring on the **build host** before building:

```bash
curl -O https://blackarch.org/strap.sh
# compare the SHA1 with the one published on https://blackarch.org/downloads.html
sha1sum strap.sh
chmod +x strap.sh && sudo ./strap.sh
```

`build-iso.sh` refuses to start a BlackArch build without it, rather than
failing 40 minutes in on a signature error.

If you would rather not bake thousands of tools into the image, skip this and
run `hexforge-toolkit enable-blackarch` inside the live system instead.

## The preflight check

Before `mkarchiso` starts, `build-iso.sh` syncs the package databases into a
throwaway directory and checks every name in the resolved set. A typo or a
renamed package fails in seconds rather than forty minutes in, and it reports
*all* the bad names at once instead of stopping at the first:

```
2 package name(s) do not resolve:
  vulkan-mesa-layers
  python-pwntools

Nothing has been built. Fix the names in packages/*.list, then try again.
```

Skip it with `--skip-preflight` if you are offline and know the set is good.

A second class of failure — two packages in the set that *conflict* — is
caught earlier still, by `./scripts/lint.sh`, which needs no network at all.

## When a build fails

**`error: target not found: <package>`** — a package was renamed or moved to
the AUR. The preflight above should have caught this; if you skipped it, run
`./scripts/verify-packages.sh --docker`, then fix the name in
`packages/*.list`. If it moved to the AUR, move the line to
`packages/aur-optional.list`.

**`error: unresolvable package conflicts` or a replacement prompt that hangs**
— two packages in the set cannot coexist. `./scripts/lint.sh` checks the known
mutually-exclusive pairs; add the new one to the `CONFLICTS` table there so it
stays caught.

**`failed to setup loop device` / `mount: permission denied`** — the container
is not privileged, or you are not root.

**`No space left on device`** — `work/` holds the uncompressed root filesystem
*and* the squashfs image. A `full` build peaks around 22 GB. Point `--work` at
a bigger disk.

**Signature or corruption errors from pacman** — usually a stale mirror. On the
host: `sudo pacman -Sy archlinux-keyring && sudo pacman -Syu`, then retry.

**It downloads everything again every time** — bind-mount a pacman cache into
the build: `--work` is scratch, but you can point the host's
`/var/cache/pacman/pkg` into the container with an extra `-v` if you build
often.

## Reproducibility

Arch is a rolling release: two builds a week apart contain different package
versions. The image records what it was built from:

- `/usr/local/share/hexforge/packages/` — the manifests used
- `/root/hexforge-pkglist.txt` — written by mkarchiso, exact versions

For a byte-reproducible build you need a pinned mirror (e.g. the [Arch Linux
Archive](https://archive.archlinux.org/)). Point `Server =` in
`profile/pacman.conf` at a dated snapshot:

```
Server = https://archive.archlinux.org/repos/2026/01/15/$repo/os/$arch
```
