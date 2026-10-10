# UndraByte on Android (native, no emulation)

A phone is not a PC: you can't boot a desktop Linux ISO on it, and you can't
replace Android/iOS on arbitrary hardware. But on **Android** you can run a
**native Arch Linux ARM desktop** — UndraByte's tools and an XFCE desktop —
on the phone's own CPU, with **no emulation and no architecture lag**, inside
the free **Termux** app, viewed through a VNC app.

> iPhone/iPad: not possible. Apple locks the bootloader, and third-party VM
> apps can only emulate x86 slowly. There is no fast/native path on iOS.

## What works / what doesn't

**Works:** the XFCE desktop, coding (Python, Node, Go, Git, build tools),
editors and a terminal, light network recon (`nmap`, `whois`, `curl`, SSH),
and general Linux use — all at native ARM speed.

**Does not work on a phone (any tool needing real hardware or kernel access):**
WiFi monitor-mode / handshake capture / cracking, raw-socket tools, Bluetooth
attacks, GPU gaming. A sandboxed app cannot reach that hardware — this is an
Android limitation, not UndraByte's.

## Setup (once)

1. Install **Termux** from **F-Droid** (the Play Store build is outdated —
   use https://f-droid.org/packages/com.termux/).
2. Open Termux and run:

   ```sh
   pkg install -y curl
   curl -fsSL https://raw.githubusercontent.com/undirboy/tuff-bi-67/claude/linux-hacking-gaming-os-vbiap4/mobile/undrabyte-mobile -o undrabyte-mobile
   bash undrabyte-mobile install
   ```

   This downloads ~1–1.5 GB (Arch ARM + the desktop and tools) and asks you to
   set a **VNC password**. Give it 10–20 minutes on a decent connection.

3. Install a **VNC viewer** app: **AVNC**, **bVNC**, or **RealVNC Viewer**
   (all free).

## Every time you want the desktop

In Termux:

```sh
bash undrabyte-mobile start
```

Then open your VNC viewer and connect to **`127.0.0.1:5901`** with the password
you set. You'll get the XFCE desktop. Rotate the phone to **landscape** for
room. Bigger canvas:

```sh
UNDRABYTE_GEOM=1600x900 bash undrabyte-mobile start
```

Stop it when done:

```sh
bash undrabyte-mobile stop
```

## Tips

- Keep Termux alive in the background: enable **acquire-wakelock** from the
  Termux notification, or disable battery optimisation for Termux, so Android
  doesn't kill the session.
- A shell inside the system without the desktop: `bash undrabyte-mobile shell`.
- Install more tools from inside: `sudo pacman -S <package>`.
- Better performance than VNC is possible with **termux-x11**, but VNC works
  everywhere and is the simplest to get going.
