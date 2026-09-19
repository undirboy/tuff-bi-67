# Making it yours

## Add or remove packages

Edit the manifests in `packages/`. One package per line; `#` comments and
blank lines are ignored.

```bash
echo 'obsidian' >> packages/70-extras.list
./scripts/verify-packages.sh --docker     # does that name exist?
make packages                             # what does the set look like now?
```

Files are numbered by concern, and the edition decides which are used:

| File | In which editions |
|---|---|
| `00-base.list` | all |
| `10-hardware.list` | all, unless `--vm-only` |
| `20-vm-guest.list` | all |
| `30-desktop-<de>.list` | whichever `--desktop` you picked |
| `45-lite.list` | lite only — a small curated hacking/coding set |
| `40-dev.list` | dev, security, full |
| `50-security.list` | security, full |
| `60-gaming.list` | gaming, full |
| `70-extras.list` | dev, security, gaming, full |
| `90-blackarch.list` | only with `--with-blackarch` |
| `95-nvidia.list` | only with `--with-nvidia` |
| `aur-optional.list` | never baked in; installed later by `undrabyte-toolkit aur` |

## Add a new edition

In `scripts/lib/common.sh`, extend the `case` in `edition_lists()`. Mirror it
in the `resolve_packages()` case inside
`profile/airootfs/usr/local/bin/undrabyte-install`, then add the name to the
matrix loop in `scripts/lint.sh`. Three small edits, and `./scripts/lint.sh`
will tell you if you missed one.

## Add a new desktop

Create `packages/30-desktop-<name>.list`, then teach `build-iso.sh` which
display-manager unit to symlink (the `case $DESKTOP` block near "Display
manager wiring"). For a DM other than SDDM or LightDM, add an autologin
branch to `profile/airootfs/usr/lib/undrabyte/live-setup.sh`.

## Change the live credentials

`profile/airootfs/etc/undrabyte/live.conf`:

```sh
UNDRABYTE_LIVE_USER=forge
UNDRABYTE_LIVE_PASSWORD=forge
UNDRABYTE_LIVE_NOPASSWD_SUDO=1      # 0 = require a password for sudo
UNDRABYTE_LIVE_ROOT_ENABLED=0       # 1 = unlock root with the same password
```

A published password on a live image is fine on your own lab network and a bad
idea anywhere else. If the image will boot somewhere you do not control, set a
real password and `UNDRABYTE_LIVE_NOPASSWD_SUDO=0`.

## Ship your own dotfiles

Anything in `profile/airootfs/etc/skel/` is copied into the live user's home
directory. Drop in a `.config/nvim/`, a `.tmux.conf`, a shell theme — it is
just a filesystem overlay.

## Ship your own scripts

Put them in `profile/airootfs/usr/local/bin/` and add a `file_permissions`
entry in `profile/profiledef.sh`:

```sh
["/usr/local/bin/my-tool"]="0:0:755"
```

Without that entry the file is copied with the permissions git gave it, and
git does not track the executable bit reliably enough to rely on here.

## Enable a service on the live image

archiso does not run `systemctl enable`, so ship the symlink:

```bash
ln -sfn /usr/lib/systemd/system/sshd.service \
  profile/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service
```

`scripts/lint.sh` checks that every such symlink points somewhere plausible.

> Think twice before enabling `sshd` on an image with a published password.

## Rebrand it

- `profile/airootfs/usr/lib/os-release` — name, ID, URLs
- `profile/profiledef.sh` — `iso_name`, `iso_label`, `iso_publisher`
- `profile/grub/grub.cfg` and `profile/syslinux/archiso_*.cfg` — boot menus
- `profile/airootfs/usr/local/bin/undrabyte-welcome` — the ASCII banner
- `profile/airootfs/etc/motd` — the console message

`iso_label` becomes the filesystem label the initramfs searches for, so keep
it uppercase, short and free of punctuation.

## Pin package versions

Point the repositories in `profile/pacman.conf` at a dated
[Arch Linux Archive](https://archive.archlinux.org/) snapshot:

```
[core]
Server = https://archive.archlinux.org/repos/2026/01/15/$repo/os/$arch
```

Two builds from the same snapshot contain the same package versions.
