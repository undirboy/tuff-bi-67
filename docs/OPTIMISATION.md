# Optimisation

A virtual machine and a laptop want opposite things. The VM should stop doing
work the host is already doing — scheduling I/O, managing thermals, balancing
interrupts — and spend those cycles on the desktop. Bare metal should do all
of it, because nothing else will.

`hexforge-optimize` detects which one you are and applies the right set.

```bash
hexforge-optimize status              # what is tuned, and what is not
sudo hexforge-optimize apply          # detect the platform, tune for it
sudo hexforge-optimize apply vm       # force the VM profile
sudo hexforge-optimize apply metal    # force the bare-metal profile
sudo hexforge-optimize apply --aggressive
sudo hexforge-optimize revert         # undo everything it did
      --dry-run                       # print every change, make none
```

It runs automatically on first boot of the live image. On an installed system,
run it once after installing.

## What each profile does

| | Virtual machine | Bare metal |
|---|---|---|
| I/O scheduler | `none` on virtio and NVMe — the host already schedules the real device, a second scheduler only adds latency | `none` on NVMe, `bfq` on spinning disks, `mq-deadline` on SATA SSDs |
| Journald | `Storage=volatile`, 100 MB cap — logs on an ephemeral guest are not worth the writes | `Storage=persistent`, 500 MB cap |
| Thermals | `thermald`, `tlp`, `power-profiles-daemon`, `irqbalance` **off** — the host owns the hardware | `thermald` on Intel, `irqbalance` on 4+ cores, `power-profiles-daemon` when a battery is present |
| Disk services | `smartd` and `lvm2-monitor` off; `fstrim.timer` **on**, so discards reach the host image | `fstrim.timer` on |
| Guest agents | left running | turned off — nothing to talk to |
| Software rendering | `LP_NUM_THREADS` set to the core count; llvmpipe uses **one** thread otherwise, which is most of why a GPU-less desktop feels slow | untouched — the real driver decides |

## What both profiles do

**zram**, sized to the machine: the full RAM size at 4 GB or less, 4 GB at
8 GB, half of RAM (capped at 8 GB) above that. Compressed swap in RAM is the
single biggest win on a small guest — typically 1.5–2× the usable memory.

**sysctl**, in `/etc/sysctl.d/98-hexforge-optimize.conf`:

- `vm.swappiness` — 10 normally, but **100** at ≤6 GB. Counter-intuitive
  until you notice that swapping to compressed RAM is far cheaper than
  dropping the page cache and re-reading from a virtual disk.
- `vm.dirty_ratio` / `dirty_background_ratio` — 10/5, so large writes do not
  build a huge dirty pile and then stall the desktop flushing it.
- `fs.inotify.max_user_watches` — 524288, because editors, file managers and
  IDEs all want watches and the default runs out quietly.
- `kernel.sched_autogroup_enabled` — keeps an interactive session responsive
  while a build runs.

The image also ships, independent of the profile:
`vm.max_map_count` for Proton, `nofile` limits for esync, and realtime
priority for the `audio` group (see `ARCHITECTURE.md`).

## `--aggressive`

Trades background work and eye-candy for responsiveness. Worth it on a 4 GB
guest, unnecessary on a workstation:

- disables KDE's **baloo** file indexer, which is the largest idle cost on a
  small machine
- stops `packagekit`, `man-db.timer` and the `updatedb` timers

## Undoing it

Every change is recorded in `/var/lib/hexforge/optimize.state` — files
written, units enabled, units disabled — and `revert` walks that list
backwards. It is not a guess about what the defaults were; it is a log of what
was actually changed.

```bash
sudo hexforge-optimize revert
```

## Checking your work

```bash
hexforge-optimize status
```

reports the detected platform, memory, cores, whether there is a battery, the
applied profile, the scheduler on every block device, zram size and current
swappiness — plus the list of changes on record.

For graphics and hypervisor integration specifically, `hexforge-vmcheck` is
the better tool; it prints the **host-side** fix for anything that is wrong.

## What it deliberately does not do

- **It does not disable the random seed, auditing, or anything security
  relevant.** Those show up on "Linux tweaks" lists and are not optimisations.
- **It does not overclock, change CPU governors globally, or set `mitigations=off`.**
  GameMode already switches the governor for the duration of a game, which is
  the version of that idea with an off switch.
- **It does not touch the bootloader or the initramfs.** Nothing it does can
  stop the machine from booting.
