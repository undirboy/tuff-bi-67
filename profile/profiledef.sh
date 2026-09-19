#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# HexForge Linux - archiso profile definition.
#
# mkarchiso sources this file; every variable below is part of archiso's
# documented profile API (see `man 1 mkarchiso` and /usr/share/archiso).
# Do not run this file directly.

_profile_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# The build script stages a copy of this profile and drops a `version` file
# next to it. Fall back to the repo VERSION, then to a date stamp, so the
# profile still builds when invoked directly with `mkarchiso -v -w work -o out .`
if [[ -r "${_profile_dir}/version" ]]; then
    iso_version="$(< "${_profile_dir}/version")"
elif [[ -r "${_profile_dir}/../VERSION" ]]; then
    iso_version="$(< "${_profile_dir}/../VERSION")"
else
    iso_version="$(date +%Y.%m.%d)"
fi

iso_name="hexforge"
iso_label="HEXFORGE_$(date +%Y%m)"
iso_publisher="HexForge Linux <https://github.com/undirboy/tuff-bi-67>"
iso_application="HexForge Linux - hacking, coding and gaming live system"
install_dir="hexforge"
arch="x86_64"
pacman_conf="pacman.conf"

buildmodes=('iso')

# GRUB owns the UEFI path (it is the most forgiving across OVMF, VirtualBox
# and VMware firmware); syslinux owns legacy BIOS. systemd-boot is
# deliberately not used: it would fight GRUB over EFI/BOOT/BOOTX64.EFI.
bootmodes=(
    'bios.syslinux.mbr'
    'bios.syslinux.eltorito'
    'uefi-x64.grub.esp'
    'uefi-x64.grub.eltorito'
)

airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')

# mkarchiso declares this associative array before sourcing the profile;
# declaring it here too keeps the file safe to source on its own (tests, lint).
declare -A file_permissions
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/10-wheel"]="0:0:440"
  ["/root"]="0:0:750"
  ["/usr/local/bin/hexforge"]="0:0:755"
  ["/usr/local/bin/hexforge-welcome"]="0:0:755"
  ["/usr/local/bin/hexforge-theme"]="0:0:755"
  ["/usr/local/bin/hexforge-optimize"]="0:0:755"
  ["/usr/local/bin/hexforge-toolkit"]="0:0:755"
  ["/usr/local/bin/hexforge-install"]="0:0:755"
  ["/usr/local/bin/hexforge-vmcheck"]="0:0:755"
  ["/usr/local/bin/hexforge-game"]="0:0:755"
  ["/usr/local/bin/hexforge-wifi"]="0:0:755"
  ["/usr/lib/hexforge/live-setup.sh"]="0:0:755"
)
