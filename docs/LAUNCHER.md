# The launcher, dark mode and the desktop

## `hexforge` — the launcher

```bash
hexforge              # open it
hexforge security     # jump straight to a section
hexforge --list       # print the whole menu tree, no TUI
```

One place to reach everything on the image: the security toolkit, the
development tools, the gaming stack, system tuning, the theme, and the docs.

**Keys**: `↑↓` or `j`/`k` to move, `Enter` to run, `1`–`9` to jump straight to
an item, `Esc`/`Backspace` to go back, `t` to toggle the theme, `q` to quit.

It is a terminal UI, deliberately. A GTK panel would look slightly nicer on
the desktop and be useless over SSH, on a TTY, on the headless edition, and
during a rescue boot. This runs identically everywhere — which is the point
of an image that is meant to work the same locally and virtually.

Two details that make it pleasant rather than merely functional:

- **Anything not installed is greyed out**, not hidden and not a crash. On a
  `lite` image you can see that Ghidra exists and simply is not here.
- **GUI applications launch detached**, so the launcher stays up; terminal
  tools take over the screen and hand it back when they exit.

It appears in the desktop applications menu as *HexForge Launcher*, and on the
live desktop as *HexForge — start here*.

## `hexforge-theme` — dark mode

The image is **dark by default**. `hexforge-live-setup.service` applies the
theme before the display manager starts, so you never see a white flash and
then have to go hunting through settings dialogues.

```bash
hexforge-theme          # what is set now
hexforge-theme dark
hexforge-theme light
hexforge-theme toggle   # or press `t` anywhere in the launcher
hexforge-theme dark --system    # also write it into /etc/skel (root)
```

A half-themed desktop — GTK apps dark, Qt apps blinding white — is worse than
either, so one command covers all of it:

| Layer | What gets set |
|---|---|
| GTK 3 / GTK 4 | `settings.ini`: theme, icons, cursor, `prefer-dark` |
| libadwaita | `org.gnome.desktop.interface color-scheme` (GNOME apps ignore the theme name) |
| Qt / KDE | `plasma-apply-colorscheme`, and `kdeglobals` written directly so it works before a session exists |
| Qt outside Plasma | `QT_QPA_PLATFORMTHEME`, but only naming a plugin that is actually installed |
| XFCE | `xfconf` xsettings and xfwm4 |
| Console | a legible 16-colour palette for the TTY |

Themes are picked from what is present: Breeze-Dark when the Breeze packages
are installed, Adwaita-dark otherwise. A theme name that is not installed
looks worse than no theme at all, so it checks first.

Change the default for built images in
`profile/airootfs/etc/hexforge/theme` (`dark` or `light`).

## The desktop defaults

Shipped in `/etc/skel`, so every account starts the same way:

**KDE Plasma** — Breeze Dark, Breeze widget style, breeze-dark icons. `kwinrc`
trims the compositor: blur and background contrast off, animation speed
raised, `LatencyPolicy=Low`. Those defaults are what make Plasma feel slow on
virtio-gpu or llvmpipe; the window manager still composites, it just stops
doing the expensive parts.

**XFCE** — Breeze-Dark for both GTK and xfwm4, Noto Sans 10, JetBrains Mono
Nerd Font for monospace, slight hinting with RGB subpixel order, event sounds
off. Compositing starts **off**, because it costs real frames when the GPU is
llvmpipe; `hexforge-optimize` turns it back on where there is hardware
acceleration to spend.

**Both** — no desktop search indexer running by default on a small image (see
[OPTIMISATION.md](OPTIMISATION.md)), and a `Desktop/` shortcut that opens the
launcher.

## Changing any of it

These are ordinary config files in the profile — see
[CUSTOMISING.md](CUSTOMISING.md):

```
profile/airootfs/etc/skel/.config/kdeglobals                     KDE colours
profile/airootfs/etc/skel/.config/kwinrc                         KDE effects
profile/airootfs/etc/skel/.config/xfce4/xfconf/…/xsettings.xml   XFCE theme and fonts
profile/airootfs/etc/skel/.config/xfce4/xfconf/…/xfwm4.xml       XFCE window manager
profile/airootfs/etc/hexforge/theme                              default mode
profile/airootfs/usr/share/applications/hexforge*.desktop        menu entries
```

To add an entry to the launcher, edit the matching `menu_*` function in
`profile/airootfs/usr/local/bin/hexforge`. Each line is
`kind|label|description|command`, where `kind` is `run` (takes over the
terminal), `gui` (launches detached), `menu` (a submenu) or `note` (a
separator).
