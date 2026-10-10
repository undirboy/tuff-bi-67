# Snapshots & rollback

A bad update, a wrong command, a package that breaks your desktop — on a
rolling-release system these happen. `undrabyte-snapshot` makes them a
one-step recovery instead of a reinstall.

## How it works

The tool adapts to your filesystem:

- **Btrfs root (recommended).** Snapshots are real, instant, copy-on-write
  copies of the `@` subvolume, stored in `@snapshots` (mounted at
  `/.snapshots`). They take no space until files change, and you can roll the
  whole system back to one. If you installed with
  `undrabyte-install --fs btrfs`, this is already set up.
- **snapper.** If you have snapper configured for `root`, the tool uses it, so
  its snapshots show up in the usual snapper tooling.
- **Anything else (ext4, …).** The filesystem can't be snapshotted live, so the
  tool records a *manifest* instead — the exact set of installed packages plus
  key configs. `restore` replays the package set, which is what usually bites
  after a bad upgrade. For true rollback, install on Btrfs.

## Everyday use

```
undrabyte-snapshot                 # list snapshots
sudo undrabyte-snapshot create "before trying the nvidia beta"
sudo undrabyte-snapshot list
sudo undrabyte-snapshot prune      # keep the newest few (default 5)
sudo undrabyte-snapshot delete <id>
```

You rarely have to run `create` yourself: **`undrabyte-update` takes a
`pre-update` snapshot automatically** before it upgrades anything. Skip it with
`undrabyte-update --no-snapshot`, or change how many are kept with
`UNDRABYTE_SNAPSHOT_KEEP=10`.

## Rolling back (Btrfs)

```
sudo undrabyte-snapshot restore <id>
```

The tool prints the exact, safe steps: boot the UndraByte live medium, rename
the current `@` out of the way, promote the chosen snapshot to `@`, and reboot.
Your old system is kept as `@_old_<id>` until you're sure the rollback is good.
Doing this from a live session (rather than against the running root) is
deliberate — it's the way that can't leave you with an unbootable machine.

With snapper, roll back with its own commands, e.g.
`snapper -c root undochange <id>..0`.
