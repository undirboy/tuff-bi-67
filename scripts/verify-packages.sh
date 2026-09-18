#!/usr/bin/env bash
#
# Check every name in packages/*.list against the real Arch repositories.
#
# Package names drift: things get renamed (vulkan-mesa-layers -> vulkan-swrast),
# moved to the AUR, or dropped. A typo only shows up 40 minutes into a build,
# so check first.
#
#   ./scripts/verify-packages.sh            # uses the local pacman
#   ./scripts/verify-packages.sh --docker   # uses an archlinux container
#
# It syncs into a throwaway database using the repository's own
# profile/pacman.conf, so it checks against exactly the repositories a build
# would use - multilib included - and never touches the host's pacman setup.
#
# Exits non-zero if any name in the official lists cannot be resolved.
# aur-optional.list and 90-blackarch.list are reported but never fatal:
# they are not expected to exist in core/extra/multilib.

set -uo pipefail

_self="${BASH_SOURCE[0]}"
[[ -L $_self ]] && _self="$(readlink "$_self")"
# shellcheck source=scripts/lib/common.sh
source "$(cd -- "$(dirname -- "$_self")" && pwd)/lib/common.sh"

ROOT="$(repo_root)"
USE_DOCKER=0
[[ ${1-} == --docker ]] && USE_DOCKER=1

if (( USE_DOCKER )); then
    command -v docker &>/dev/null || die "docker not found"
    log "checking inside an archlinux container"
    exec docker run --rm -v "$ROOT:/repo:ro" archlinux:latest \
        bash -c "pacman -Sy --noconfirm --needed >/dev/null 2>&1; cp -r /repo /tmp/repo && /tmp/repo/scripts/verify-packages.sh"
fi

command -v pacman &>/dev/null || die "pacman not found - run with --docker on a non-Arch host"

CONF="$ROOT/profile/pacman.conf"
[[ -r $CONF ]] || die "missing $CONF"

DBPATH="$(mktemp -d)"
trap 'rm -rf "$DBPATH"' EXIT

log "syncing the databases named in profile/pacman.conf (into a throwaway dbpath)"
INDEX="$DBPATH/index"
if ! repo_package_index "$CONF" "$DBPATH" > "$INDEX"; then
    die "could not sync the package databases.
     On a non-Arch host use --docker. In a container you may first need:
       pacman-key --init && pacman-key --populate archlinux"
fi

# Guard against the failure that made an earlier CI run lie: if a repository
# silently did not sync, every name from it looks missing. Check that the
# repositories the build expects are actually present before trusting a
# single result.
mapfile -t WANTED_REPOS < <(grep -oP '^\[\K[^]]+' "$CONF" | grep -v '^options$')
missing_repos=()
for repo in "${WANTED_REPOS[@]}"; do
    if ! pacman --config "$CONF" --dbpath "$DBPATH" -Sl "$repo" &>/dev/null; then
        missing_repos+=("$repo")
    fi
done
if (( ${#missing_repos[@]} )); then
    die "these repositories did not sync: ${missing_repos[*]}
     Every package from them would be reported missing, so this run would be
     meaningless. Fix the mirrors or the keyring and try again."
fi
ok "repositories synced: ${WANTED_REPOS[*]}"
log "$(wc -l < "$INDEX") packages visible across them"

missing_required=0
shopt -s nullglob
for list in "$ROOT"/packages/*.list; do
    base="$(basename "$list")"
    optional=0
    [[ $base == aur-optional.list || $base == 90-blackarch.list ]] && optional=1

    mapfile -t names < <(grep -vE '^[[:space:]]*(#|$)' "$list")
    (( ${#names[@]} )) || { ok "$base (empty)"; continue; }
    mapfile -t missing < <(missing_packages "$INDEX" "$CONF" "$DBPATH" "${names[@]}")

    if (( ${#missing[@]} == 0 )); then
        ok "$base"
    elif (( optional )); then
        printf '%s note%s %s: not in the official repos (expected): %s\n' \
            "$C_DIM" "$C_RST" "$base" "${missing[*]}"
    else
        printf '%sFAIL%s %s: %d unresolved name(s)\n' "$C_RED" "$C_RST" "$base" "${#missing[@]}"
        printf '       %s\n' "${missing[@]}"
        missing_required=$(( missing_required + ${#missing[@]} ))
    fi
done

# ------------------------------------------------- the airootfs overlay --
#
# mkarchiso lays profile/airootfs/ into the work directory before pacstrap
# runs, so a path we ship that a package also owns is a file conflict and the
# entire transaction aborts - about a minute into a build that was going to
# take an hour. Every such path needs a NoExtract entry in the build
# pacman.conf. Work out which ones those are from the file database.

log "checking the airootfs overlay against package file ownership"
if pacman --config "$CONF" --dbpath "$DBPATH" -Fy &>/dev/null; then
    mapfile -t noextract < <(grep -oP '^[[:space:]]*NoExtract[[:space:]]*=[[:space:]]*\K.*' "$CONF" \
                             | tr ' ' '\n' | grep -v '^$')
    needs_noextract=()
    while IFS= read -r file; do
        rel="${file#"$ROOT"/profile/airootfs/}"
        covered=0
        for pattern in "${noextract[@]}"; do
            # shellcheck disable=SC2053  # glob match is what NoExtract does
            [[ $rel == $pattern ]] && { covered=1; break; }
        done
        (( covered )) && continue
        owner="$(pacman --config "$CONF" --dbpath "$DBPATH" -Fq "$rel" 2>/dev/null | head -1)"
        [[ -n $owner ]] && needs_noextract+=("$rel  (owned by $owner)")
    done < <(find "$ROOT/profile/airootfs" -type f)

    if (( ${#needs_noextract[@]} )); then
        printf '%sFAIL%s %d overlay file(s) collide with a package:\n' \
            "$C_RED" "$C_RST" "${#needs_noextract[@]}"
        printf '       %s\n' "${needs_noextract[@]}"
        printf '\n       pacstrap aborts on these. Add to profile/pacman.conf:\n'
        printf '       NoExtract    = %s\n' "${needs_noextract[@]%%  (*}"
        missing_required=$(( missing_required + ${#needs_noextract[@]} ))
    else
        ok "no overlay file collides with a package"
    fi
else
    warn "could not sync the file databases; skipped the overlay check"
fi

printf '\n'
if (( missing_required )); then
    printf '%s%d package name(s) do not resolve.%s\n' "$C_RED" "$missing_required" "$C_RST"
    printf 'Find the new name with: pacman -Ss <partial>\n'
    printf 'If it moved to the AUR, move the line to packages/aur-optional.list\n'
    exit 1
fi
printf '%sEvery required package name resolves.%s\n' "$C_GRN" "$C_RST"
