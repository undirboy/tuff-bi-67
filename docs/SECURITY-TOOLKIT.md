# The security toolkit

## Read this first

Everything below is a professional tool with a legitimate use and an illegal
one. The line is **authorisation**: you may test systems you own, or systems
whose owner has given you written permission to test. Scanning, cracking,
intercepting or exploiting anything else is a criminal offence in most
jurisdictions — the Computer Fraud and Abuse Act in the US, the Computer
Misuse Act in the UK, §202 StGB in Germany, and equivalents almost everywhere
else. "It was just a scan" is not a defence, and neither is "the tool made it
easy".

Build a lab. The last section shows how.

## What's on the image

Installed from the official Arch repositories (`packages/50-security.list`):

| Area | Tools |
|---|---|
| Recon & scanning | nmap, masscan, arp-scan, gobuster, ffuf, whois, dig |
| Traffic | Wireshark (GUI + CLI), tcpdump, tcpreplay, mitmproxy, bettercap, ettercap, socat, netcat, sshuttle |
| Wireless | aircrack-ng, hcxtools, hcxdumptool, kismet, hostapd, macchanger |
| Web & exploitation | sqlmap, Metasploit, exploitdb (searchsploit), impacket |
| Passwords | hashcat (+utils), John the Ripper, hydra |
| Reverse engineering | Ghidra, radare2, rizin, Cutter, binwalk, yara |
| Forensics | sleuthkit, testdisk, ddrescue, fsarchiver |
| Defensive | lynis, clamav, nftables, usbguard |
| Anonymity | tor, torsocks, proxychains-ng, OpenVPN, OpenConnect, WireGuard |
| Scripting | python-scapy, the full Python/Go/Rust toolchains from the dev set |

## Adding BlackArch (~3000 more tools)

[BlackArch](https://blackarch.org) is an Arch repository, so it layers onto a
running system cleanly.

```bash
hexforge-toolkit enable-blackarch     # installs the signing keyring + mirrorlist
hexforge-toolkit groups               # what's available
sudo hexforge-toolkit install recon webapp
```

Sizes are real: `recon` alone is around 1.5 GB, and installing every group is
over 20 GB. Install the groups you need.

To bake them into the ISO instead, build with `--with-blackarch` — see
[BUILDING.md](BUILDING.md), which also covers the keyring the build host needs.

## AUR tools

Some staples are not in any binary repository: Burp Suite, nuclei, subfinder,
amass, feroxbuster, netexec, BloodHound, SecLists, pwndbg, volatility3. They
are listed in `packages/aur-optional.list` and built on demand:

```bash
sudo hexforge-toolkit aur                 # the whole curated list
sudo hexforge-toolkit aur seclists pwndbg # or just these
```

This bootstraps `paru` first and builds as your unprivileged user. They are
deliberately not in the ISO: building AUR packages during an image build makes
it slow and non-reproducible, and AUR PKGBUILDs are user-submitted code.

## Things that need a setup step

**Wireshark without sudo** — log out and back in after first boot; the package
adds a `wireshark` group and the live user is already in it.

**Metasploit's database** — `msfdb` wants PostgreSQL:

```bash
sudo pacman -S postgresql
sudo -u postgres initdb -D /var/lib/postgres/data
sudo systemctl enable --now postgresql
sudo msfdb init
```

**Monitor mode** — needs a card whose driver supports it, and passed through
to the VM as a USB device (`-device usb-host,...` in QEMU, or USB passthrough
in VirtualBox/VMware). A virtio NIC cannot do monitor mode; no configuration
changes that.

```bash
sudo airmon-ng check kill
sudo airmon-ng start wlan0
```

**Ghidra and Burp** need a JVM — `jdk-openjdk` is in the dev package set, which
the `security` and `full` editions include.

## Building a lab you're allowed to attack

The image already carries everything needed to host the targets as well as the
attacker, because `libvirt`, `qemu-full` and `docker` are in the dev set.

**Vulnerable targets, in Docker, in minutes:**

```bash
sudo systemctl start docker
docker run -d -p 8080:80 vulnerables/web-dvwa          # DVWA
docker run -d -p 3000:3000 bkimminich/juice-shop       # OWASP Juice Shop
docker run -d -p 8081:80 citizenstig/nowasp            # Mutillidae
```

**Whole vulnerable machines:** Metasploitable 2/3, or any of the
[VulnHub](https://www.vulnhub.com/) images, as a second VM on an isolated
host-only network.

**Isolate the lab network.** In libvirt, create an isolated network so target
VMs cannot reach the internet or your LAN:

```xml
<network>
  <name>hexforge-lab</name>
  <bridge name='virbr-lab'/>
  <ip address='10.99.0.1' netmask='255.255.255.0'>
    <dhcp><range start='10.99.0.100' end='10.99.0.200'/></dhcp>
  </ip>
</network>
```

Leave out the `<forward/>` element and the network has no route off the host —
which is the point. A misconfigured scan that escapes into your ISP's network
is how a lab exercise becomes a police matter.

**Legal practice targets on the public internet:** HackTheBox, TryHackMe,
PortSwigger Web Security Academy, OverTheWire, PentesterLab, and vendor bug
bounty programmes — each with scope rules you are expected to read and follow.

## Hardening the image itself

The live session is built for convenience: a known password and passwordless
sudo. Before using it anywhere that matters:

```bash
sudo passwd forge                              # a real password
sudo rm /etc/sudoers.d/99-hexforge-live        # require a password for sudo
sudo systemctl enable --now nftables           # a firewall
sudo lynis audit system                        # see what else is loose
```

Or build the image with `HEXFORGE_LIVE_NOPASSWD_SUDO=0` and a real password in
`profile/airootfs/etc/hexforge/live.conf` — see [CUSTOMISING.md](CUSTOMISING.md).

`sshd` is installed but **not enabled**, deliberately: a live image with a
published password and an open SSH port is a machine someone else owns.
