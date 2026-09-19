# Using the desktop — no commands needed

UndraByte is a normal graphical desktop. Everything you'd do on Windows with a
mouse, you do here with a mouse. The terminal and the `undrabyte` launcher are
there when you want them, not because you need them.

If you build the **XFCE** edition (the default for `lite`, and the one for
low-end machines), it looks and works much like Windows: a taskbar along the
bottom, a Start-style menu, a system tray with the clock and network icon, and
a file manager that behaves like Explorer.

## Making a folder — like Windows

1. Open **Files** (the file manager, Thunar) from the menu or the taskbar.
2. Go where you want it — **Home**, **Documents**, **Desktop**, wherever.
3. **Right-click an empty area → Create Folder** (or press `Ctrl+Shift+N`).
4. Type the name, press Enter.

That's it. No commands. Right-click also gives you Copy, Paste, Rename,
Move to Trash, and Extract for zip files — the same menu you expect.

## The Windows-to-UndraByte cheat sheet

| On Windows | On UndraByte (XFCE) |
|---|---|
| Start menu | Whisker menu — click the icon bottom-left, or tap the Super (⊞) key |
| File Explorer | **Files** (Thunar) |
| Desktop, Documents, Downloads | same folders, in your Home |
| Right-click → New → Folder | Right-click → **Create Folder** |
| Double-click a .zip to open | Double-click → opens in the archive manager; right-click → **Extract Here** |
| Plug in a USB stick | It mounts automatically and appears in Files' sidebar |
| Taskbar clock / volume / WiFi | Same, in the tray (bottom-right) |
| Settings | **Settings Manager** in the menu |
| Task Manager | **Task Manager** (or `btop` in a terminal, if you like) |
| Recycle Bin | **Trash**, in the Files sidebar |
| PrintScreen | PrintScreen — saves a screenshot |
| Installing a program | KDE: **Discover** app store · any edition: one-click entries in the `undrabyte` launcher |

## Taskbar, snapping and shortcuts (XFCE)

The XFCE edition is set up to feel like Windows out of the box:

- A **bottom taskbar** with a **Start** button (left), buttons for open
  windows, and a system tray with volume and clock (right).
- **Window snapping:** drag a window to the top to maximise, or to the left/
  right edge to fill half the screen. `Super+←/→` snaps by keyboard.
- **Desktop icons** for Home, Trash, the filesystem and USB drives.
- **Clipboard history** running in the tray.

Keyboard shortcuts you already know:

| Key | Does |
|---|---|
| **Super (⊞)** | Open the Start menu |
| **Super + E** | Open Files |
| **Super + D** | Show the desktop |
| **Super + L** | Lock the screen |
| **Alt + F4** | Close the window |
| **Alt + Tab** | Switch windows |
| **PrintScreen** | Screenshot |

## Connecting to WiFi

Click the **network icon** in the tray (bottom-right), pick your network, type
the password. Exactly like Windows. (Cracking your *own* WiFi's password for
learning is a different, deliberate thing — that's `undrabyte-wifi` and
[WIFI-SECURITY.md](WIFI-SECURITY.md).)

## Installing apps without commands

- **KDE edition:** **Discover** is a full graphical app store — search, click
  Install, done, just like the Microsoft Store.
- **Any edition:** the `undrabyte` launcher has one-click entries for the big
  optional bundles — the extra security tools, the Epic/GOG game launcher —
  and does the work for you.
- **XFCE:** there is no heavyweight store preinstalled (it would undo the point
  of a light desktop on an old machine). If you want one, install
  `gnome-software` from Discover-style tooling or with a single
  `undrabyte-toolkit` step; otherwise the launcher covers the curated extras.

You never have to hand-type a `pacman` line, though you always can.

## Where the terminal actually helps

Nowhere, for everyday use. It earns its place for the things this OS is *for* —
running a port scan, driving a debugger, scripting a build — and even most of
those have a menu entry in the `undrabyte` launcher. Think of the launcher and
the terminal as the workshop, and the desktop as the house: you live in the
house.

## KDE edition

If you build the KDE Plasma edition instead, the same is all true, with
**Dolphin** as the file manager (right-click → Create New → Folder) and the
Plasma application menu as the Start menu. KDE is heavier; on a dual-core /
4 GB machine, prefer XFCE (`make iso-lite`).
