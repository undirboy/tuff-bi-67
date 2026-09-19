# WiFi security: cracking your own WPA2, wirelessly

A standard, legal way to learn how WPA2 actually holds up: capture the 4-way
handshake when a device joins **your own** access point, then try to recover
the passphrase from it offline. HexForge ships everything for it —
`aircrack-ng`, `hcxdumptool`, `hcxtools`, `hashcat`, `john` — plus
`hexforge-wifi`, which walks the whole flow.

## The one rule

Doing this to a network **you own or administer** is legal and is how the
field is taught. Doing it to any other network — a neighbour's, a café's,
your workplace's without written authorisation — is a criminal offence under
the US CFAA, the UK Computer Misuse Act, the EU cybercrime directive and
equivalents almost everywhere. Intent is judged by conduct, and "I was only
learning" has never worked as a defence. `hexforge-wifi` makes you name the
single BSSID you target and confirm you own it, precisely so it can't be
pointed at a network in passing. Point it only at your own.

## Why a plain VM can't do this

"Wirelessly" is the catch. Capturing a handshake means listening to raw
802.11 frames in the air — **monitor mode** — and often nudging a device to
reconnect — **packet injection**. Both need a real radio.

A virtual machine's NIC (`virtio-net`) is a paravirtual device with no radio
at all. It moves IP packets to the host and nothing else: no monitor mode, no
injection, no channels. Nothing you configure changes that. So there are two
ways to do this exercise:

1. **Boot HexForge on bare metal** (live USB), where it can use the laptop's
   built-in WiFi directly — if that chipset's driver supports monitor mode.
2. **Pass a USB WiFi adapter through to the VM.** The adapter is a real
   radio; QEMU hands it to the guest, and the guest's driver drives it. This
   is the usual setup and what `run-vm.sh --wifi` is for.

## You need a monitor-mode-capable adapter

Not every WiFi chip can enter monitor mode; it depends on the driver. The
laptop's built-in card often cannot, which is the other reason people use a
USB adapter. Well-supported chipsets (all have in-kernel drivers, so they
work on HexForge with no extra install):

| Chipset | Bands | Notes |
|---|---|---|
| Atheros AR9271 | 2.4 GHz | the classic, rock-solid, cheap |
| Ralink RT3070 / RT5372 | 2.4 GHz | very well supported |
| Realtek RTL8812AU | 2.4/5 GHz | dual-band; driver is in recent kernels |
| MediaTek MT7612U | 2.4/5 GHz | dual-band, good injection |

Check whether an adapter can do it, inside HexForge:

```bash
iw phy | grep -A8 'Supported interface modes'   # look for "* monitor"
```

## Do it with `hexforge-wifi`

The guided path — it picks the adapter, scans, captures and cracks, and puts
the adapter back afterwards:

```bash
hexforge-wifi           # or press it from the hexforge launcher, Security section
```

Or step by step, if you prefer to see each command:

**1. Pass the adapter to the VM** (skip if you booted on bare metal). On the
host, with the adapter plugged in:

```bash
./scripts/run-vm.sh --disk vm/hexforge.qcow2 --wifi
```

`--wifi` lists USB WiFi adapters and passes the one you choose; the device
leaves the host and belongs to the guest until the VM stops. To name it
explicitly instead: `--usb 0bda:8812` (the `lsusb` VID:PID).

**2. Scan for your network** and note its BSSID and channel:

```bash
hexforge-wifi scan
```

**3. Capture the handshake:**

```bash
hexforge-wifi capture AA:BB:CC:DD:EE:FF 6
```

A handshake only happens when a device joins the network. Either reconnect
your phone to your WiFi, or — from another terminal — nudge a device already
connected to **your** AP to reconnect, which forces one:

```bash
sudo aireplay-ng --deauth 3 -a AA:BB:CC:DD:EE:FF <monitor-iface>
```

Watch airodump's top-right for `WPA handshake: AA:BB:CC:...`, then Ctrl-C.

**4. Crack it offline:**

```bash
hexforge-wifi crack ~/wifi-captures/handshake-...-01.cap
```

This is a **dictionary attack**: it only finds the passphrase if the
passphrase is in the wordlist. HexForge does not bake in a big wordlist
(licensing and size); get the standard one with:

```bash
hexforge-toolkit aur seclists      # provides rockyou and much more
```

With a GPU, `hashcat` is far faster than `aircrack-ng`:

```bash
hcxpcapngtool -o hs.hc22000 capture-01.cap
hashcat -m 22000 hs.hc22000 /usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt
```

**5. Put the adapter back** to normal (managed) mode:

```bash
hexforge-wifi restore
```

## What this teaches

The exercise makes one lesson concrete: **WPA2's security is entirely the
passphrase.** The capture takes seconds and always succeeds; the crack is
just guessing. So:

- A passphrase in `rockyou.txt` — any common word, name, date, or pattern —
  falls in seconds to minutes. Try setting your test AP to `password123` and
  watch it drop, then to 16 random characters and watch the same attack run
  forever.
- Length and randomness are the whole game. A 20-character random passphrase
  is not in any wordlist and is not brute-forceable in a human lifetime.
- WPA3's SAE handshake is designed to kill exactly this offline attack: the
  captured exchange can't be tested against a wordlist the same way. Upgrading
  your own router to WPA3 and seeing the capture become uncrackable is the
  natural next experiment.

## Cleaning up

`hexforge-wifi restore` stops monitor mode and restarts NetworkManager. If
you passed a USB adapter through, it returns to the host when you power the
VM off.

## Legalities and licences

See [LEGAL.md](LEGAL.md). The short version, again: your own network, or one
you have written permission to test. Nothing else.
