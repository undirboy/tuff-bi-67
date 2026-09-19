#!/usr/bin/env bash
#
# Everything we can check without an Arch host: shell syntax, shellcheck,
# package-manifest hygiene, and that every edition/desktop combination
# actually resolves to a package set.

set -uo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/lib/common.sh"

ROOT="$(repo_root)"
cd "$ROOT"

failures=0
fail() { printf '%sFAIL%s %s\n' "$C_RED" "$C_RST" "$*"; failures=$((failures + 1)); }
pass() { printf '%s ok %s %s\n' "$C_GRN" "$C_RST" "$*"; }

mapfile -t SCRIPTS < <(
    find scripts profile/airootfs/usr -type f \
         \( -name '*.sh' -o -path '*/bin/undrabyte*' \) | sort
)

log "shell syntax"
for s in "${SCRIPTS[@]}"; do
    if bash -n "$s" 2>/dev/null; then pass "$s"; else fail "$s (bash -n)"; fi
done

log "shellcheck"
if command -v shellcheck &>/dev/null; then
    for s in "${SCRIPTS[@]}"; do
        if shellcheck -x -S warning "$s"; then pass "$s"; else fail "$s (shellcheck)"; fi
    done
else
    warn "shellcheck not installed - skipping"
fi

log "executable bits"
for s in "${SCRIPTS[@]}"; do
    # lib/ holds sourced helpers, which are deliberately not executable.
    [[ $s == */lib/* ]] && continue
    [[ -x $s ]] || fail "$s is not executable"
done
pass "checked ${#SCRIPTS[@]} scripts"

log "package manifests"
shopt -s nullglob
for list in packages/*.list; do
    if grep -nP '\t| $' "$list" >/dev/null; then
        fail "$list has trailing whitespace or tabs"
    fi
    if grep -q $'\r' "$list"; then
        fail "$list has CRLF line endings"
    fi
    # Package names: lowercase alnum plus - _ . + @
    if bad="$(grep -vE '^[[:space:]]*(#|$)' "$list" | grep -vE '^[a-z0-9][a-z0-9@._+-]*$' || true)"; [[ -n $bad ]]; then
        fail "$list has suspicious entries: $(tr '\n' ' ' <<<"$bad")"
    fi
    dupes="$(grep -vE '^[[:space:]]*(#|$)' "$list" | sort | uniq -d)"
    if [[ -n $dupes ]]; then
        fail "$list repeats: $(tr '\n' ' ' <<<"$dupes")"
    fi
done
pass "manifest syntax"

log "edition matrix"
for edition in full security dev gaming lite minimal; do
    for desktop in kde xfce none; do
        mapfile -t lists < <(edition_lists "$edition" "$desktop" "$ROOT/packages" 2>/dev/null)
        if (( ${#lists[@]} == 0 )); then
            fail "$edition/$desktop resolved to no lists"
            continue
        fi
        mapfile -t pkgs < <(resolve_packages "${lists[@]}" 2>/dev/null)
        if (( ${#pkgs[@]} < 40 )); then
            fail "$edition/$desktop resolved to only ${#pkgs[@]} packages"
        else
            pass "$(printf '%-9s %-5s %4d packages' "$edition" "$desktop" "${#pkgs[@]}")"
        fi
    done
done

log "package conflicts"
# pacstrap aborts (or stops to ask) when two packages in the same transaction
# conflict. verify-packages.sh cannot see this - it only checks that names
# exist - so the known mutually-exclusive pairs are checked here instead.
CONFLICTS=(
    "gnu-netcat:openbsd-netcat"
    "virtualbox-guest-utils:virtualbox-guest-utils-nox"
    "pipewire-jack:jack2"
    "pipewire-pulse:pulseaudio"
    "pipewire-alsa:pulseaudio-alsa"
    "iptables:iptables-nft"
    "code:visual-studio-code-bin"
    "vim:gvim"
    "mesa:mesa-amber"
    "sdl2:sdl2-compat"
    "cronie:systemd-cron"
    "networkmanager:connman"
)

check_conflicts() {
    local label=$1; shift
    local set_file=$1
    local pair a b hit=0
    for pair in "${CONFLICTS[@]}"; do
        a=${pair%%:*}; b=${pair#*:}
        if grep -qxF "$a" "$set_file" && grep -qxF "$b" "$set_file"; then
            fail "$label installs both $a and $b, which conflict"
            hit=1
        fi
    done
    return $hit
}

conflict_failures=0
for edition in full security dev gaming lite minimal; do
    for desktop in kde xfce none; do
        mapfile -t lists < <(edition_lists "$edition" "$desktop" "$ROOT/packages" 2>/dev/null)
        resolve_packages "${lists[@]}" 2>/dev/null > /tmp/undrabyte-lint-set.$$
        check_conflicts "$edition/$desktop" /tmp/undrabyte-lint-set.$$ || conflict_failures=1
    done
done
rm -f /tmp/undrabyte-lint-set.$$

# The AUR list is installed later onto a system that already has the baked
# set, so a conflict there bites at `undrabyte-toolkit aur` time instead.
all_baked="$(cat packages/[0-9]*.list | grep -vE '^[[:space:]]*(#|$)' | sort -u)"
while read -r aur_pkg; do
    for pair in "${CONFLICTS[@]}"; do
        a=${pair%%:*}; b=${pair#*:}
        if [[ $aur_pkg == "$b" ]] && grep -qxF "$a" <<<"$all_baked"; then
            fail "aur-optional.list offers $b, which conflicts with $a in the image"
        fi
        if [[ $aur_pkg == "$a" ]] && grep -qxF "$b" <<<"$all_baked"; then
            fail "aur-optional.list offers $a, which conflicts with $b in the image"
        fi
    done
done < <(grep -vE '^[[:space:]]*(#|$)' packages/aur-optional.list)
(( conflict_failures )) || pass "no known conflicting pairs in any edition"

log "archiso profile"
for required in profile/profiledef.sh profile/pacman.conf profile/grub/grub.cfg \
                profile/syslinux/syslinux.cfg profile/airootfs/etc/mkinitcpio.d/linux.preset; do
    if [[ -r $required ]]; then pass "$required"; else fail "missing $required"; fi
done

# profiledef.sh is sourced by mkarchiso; make sure it at least parses and
# defines the variables archiso requires.
if ( set -e; cd profile
     # shellcheck disable=SC2034
     declare -A file_permissions
     # shellcheck disable=SC1091
     source ./profiledef.sh
     for v in iso_name iso_label iso_version install_dir arch pacman_conf \
              airootfs_image_type; do
        [[ -n ${!v-} ]] || { echo "profiledef.sh does not set $v" >&2; exit 1; }
     done ) 2>/dev/null; then
    pass "profiledef.sh defines the archiso variables"
else
    fail "profiledef.sh is missing required variables"
fi

log "profiledef file_permissions"
# mkarchiso aborts if a file_permissions entry names a path that does not
# exist in the built root filesystem. Anything not shipped in airootfs/ has to
# come from a package, so it needs to be listed here deliberately.
FROM_PACKAGES=(/etc/shadow /etc/gshadow /etc/passwd /etc/group /etc/fstab /root)
while IFS= read -r path; do
    if [[ -e "profile/airootfs$path" ]]; then
        pass "$path (shipped in airootfs)"
        continue
    fi
    known=0
    for p in "${FROM_PACKAGES[@]}"; do
        [[ $path == "$p" ]] && known=1
    done
    if (( known )); then
        pass "$path (provided by a package)"
    else
        fail "profiledef.sh sets permissions on $path, which nothing provides"
    fi
done < <(grep -oP '(?<=\[")[^"]+(?="\])' profile/profiledef.sh)

log "systemd enablement symlinks"
while IFS= read -r link; do
    target="$(readlink "$link")"
    case $target in
        /usr/lib/systemd/system/*|/etc/systemd/system/*) pass "$(basename "$link") -> $target" ;;
        *) fail "$link points outside the systemd unit directories: $target" ;;
    esac
done < <(find profile/airootfs/etc/systemd -type l | sort)

printf '\n'
if (( failures )); then
    printf '%s%d check(s) failed.%s\n' "$C_RED" "$failures" "$C_RST"
    exit 1
fi
printf '%sAll checks passed.%s\n' "$C_GRN" "$C_RST"
