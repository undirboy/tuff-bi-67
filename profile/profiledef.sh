#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# UndraByte Linux - archiso profile definition.
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

iso_name="undrabyte"
iso_label="UNDRABYTE_$(date +%Y%m)"
iso_publisher="UndraByte Linux <https://github.com/undirboy/tuff-bi-67>"
iso_application="UndraByte Linux - hacking, coding and gaming live system"
install_dir="undrabyte"
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
# zstd at its maximum level keeps the squashfs (and so the ISO) as small as
# possible - it has to stay under GitHub's 2 GiB per-release-asset limit.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '22' '-b' '1M')

# mkarchiso declares this associative array before sourcing the profile, then
# sources profiledef.sh *inside a function*. A plain `declare -A` here would
# create a function-local array that shadows mkarchiso's global one, so every
# entry below would be silently discarded - no file gets its permissions,
# leaving all the /usr/local/bin/undrabyte* tools and live-setup.sh
# non-executable (the live session then fails with status=203/EXEC and never
# reaches the desktop). `declare -gA` forces global scope so the entries
# actually reach mkarchiso. It is also safe to source standalone (tests/lint).
declare -gA file_permissions
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/10-wheel"]="0:0:440"
  ["/root"]="0:0:750"
  ["/usr/local/bin/undrabyte"]="0:0:755"
  ["/usr/local/bin/undrabyte-welcome"]="0:0:755"
  ["/usr/local/bin/undrabyte-theme"]="0:0:755"
  ["/usr/local/bin/undrabyte-optimize"]="0:0:755"
  ["/usr/local/bin/undrabyte-toolkit"]="0:0:755"
  ["/usr/local/bin/undrabyte-software"]="0:0:755"
  ["/usr/local/bin/undrabyte-winapps"]="0:0:755"
  ["/usr/local/bin/undrabyte-install"]="0:0:755"
  ["/usr/local/bin/undrabyte-vmcheck"]="0:0:755"
  ["/usr/local/bin/undrabyte-game"]="0:0:755"
  ["/usr/local/bin/undrabyte-wifi"]="0:0:755"
  ["/usr/local/bin/undrabyte-set-wallpaper"]="0:0:755"
  ["/usr/local/bin/undrabyte-lab"]="0:0:755"
  ["/usr/lib/undrabyte/live-setup.sh"]="0:0:755"
)
