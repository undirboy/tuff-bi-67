# Licensing and lawful use

## The build system

The contents of this repository — scripts, archiso profile, package manifests,
documentation — are MIT licensed. See [../LICENSE](../LICENSE).

## A built ISO is a different thing

An ISO built from this repository contains several thousand packages that this
project does not own and does not relicense. Each keeps its own terms:

- most of the base system: GPL-2.0, GPL-3.0, LGPL, MIT, BSD, Apache-2.0
- **Steam**: proprietary, under the Steam Subscriber Agreement
- **NVIDIA driver** (`--with-nvidia`): proprietary NVIDIA licence
- **linux-firmware**: a mixture, including redistributable-binary-only blobs
- **Ghidra**: Apache-2.0; **Metasploit Framework**: BSD-3-Clause with the
  Rapid7 addendum
- **BlackArch** packages: whatever each upstream tool uses

If you redistribute a built image, you are redistributing all of that, and
complying with each licence — including source-offer obligations for GPL
components — is your responsibility. Building an image for yourself is
unproblematic; publishing one is a decision to make deliberately.

## Export control

Cryptographic software is export-controlled in some jurisdictions. A HexForge
image contains OpenSSL, GnuPG, WireGuard, hashcat and more. If you distribute
images across borders, check your local rules.

## Lawful use of the security tooling

This image ships tools that scan networks, intercept traffic, crack password
hashes and exploit software. They exist because defenders, researchers and
penetration testers need them. Using them against systems you do not own,
without the owner's documented permission, is a crime under — among many
others:

- **United States** — Computer Fraud and Abuse Act, 18 U.S.C. § 1030
- **United Kingdom** — Computer Misuse Act 1990
- **European Union** — Directive 2013/40/EU, as implemented nationally
- **Germany** — §§ 202a–202c, 303a–303b StGB (§ 202c covers possession of
  such tools with intent)
- **India** — Information Technology Act 2000, §§ 43, 66
- **Australia** — Criminal Code Act 1995, Part 10.7

Penalties are measured in years, and intent is judged by conduct: an
unauthorised port scan is unauthorised access whether or not you meant to go
further, and "I was learning" has not worked as a defence.

### What authorised work looks like

- A written scope: which hosts, which networks, which techniques, which dates
- Signed by someone with the authority to grant it — for cloud-hosted targets
  the provider's rules apply too (AWS, Azure, GCP each publish theirs)
- Rules of engagement covering what you do when you find something, and what
  happens to the data you collect
- Everything logged, so your activity can be told apart from a real attacker's

If you are practising rather than working: HackTheBox, TryHackMe, the
PortSwigger Web Security Academy, OverTheWire and locally hosted targets like
DVWA, Juice Shop and Metasploitable exist precisely so you have somewhere
legal to do this. [SECURITY-TOOLKIT.md](SECURITY-TOOLKIT.md) shows how to
build an isolated lab.

### On this project's part

This repository provides a build system for a general-purpose operating
system. It is offered without any warranty, and the authors accept no
liability for what anyone does with an image built from it. Nothing here is
legal advice; if your situation is unclear, ask a lawyer in your jurisdiction
before you run the scan.

## Trademarks

Arch Linux, BlackArch, Steam, NVIDIA, VirtualBox, VMware, Hyper-V and
Proxmox are trademarks of their respective owners. This project is not
affiliated with, endorsed by, or supported by any of them.
