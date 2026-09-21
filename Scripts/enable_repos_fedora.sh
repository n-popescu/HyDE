#!/usr/bin/env bash
# shellcheck disable=SC1091
#|---/ /+---------------------------------------------------+---/ /|#
#|--/ /-| Enable the RPM repos HyDE needs on Fedora / Asahi |--/ /-|#
#|-/ /--| Fedora / Fedora Asahi Remix port                  |--/ /-|#
#|/ /---+---------------------------------------------------+/ /---|#
#
# Arch's install_pre.sh reaches for pacman.conf and Chaotic-AUR here; Fedora
# has no AUR, so the equivalent is RPM Fusion (codecs, a handful of non-free
# bits), a Hyprland-ecosystem COPR (packages in Scripts/dots/*.toml's
# `dnf = [...]` arrays marked "-- COPR"), and the atim/starship COPR (Fedora
# dropped starship from its own repos after Fedora 36 -- it's needed
# unconditionally, both shells depend on it). All of this is idempotent:
# re-running after it's already enabled is a no-op.
#
# The Fedora Hyprland-on-COPR landscape churns and forks often. Confirmed on
# real Fedora Asahi Remix hardware: solopasha/hyprland (the longest-standing
# one, and the default on x86_64) has NO aarch64 chroot at all -- `dnf copr
# enable` on aarch64 fails outright with "chroot not found ... you can choose
# one of the available chroots explicitly: fedora-rawhide-x86_64". So aarch64
# defaults to lionheartp/Hyprland (a fork of solopasha's reported to build
# both aarch64 and x86_64 for Fedora 44) instead. Override
# HYDE_FEDORA_HYPRLAND_COPR to point at a different one without editing this
# script -- this landscape moves fast enough that either default can go
# stale. See FEDORA-ASAHI.md.

scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

if ! is_fedora; then
    print_log -sec "repos" -warn "not Fedora, skipping RPM Fusion / COPR setup"
    exit 0
fi

flg_DryRun=${flg_DryRun:-0}
export log_section="repos"

run() {
    if [ "${flg_DryRun}" -eq 1 ]; then
        print_log -y "[dry-run] " "$*"
    else
        "$@"
    fi
}

if ! rpm -q dnf-plugins-core &>/dev/null; then
    print_log -g "[dnf] " -b "install :: " "dnf-plugins-core (needed for 'dnf copr')"
    run sudo dnf install -y dnf-plugins-core
fi

fedora_ver="$(rpm -E %fedora)"

if rpm -q rpmfusion-free-release &>/dev/null && rpm -q rpmfusion-nonfree-release &>/dev/null; then
    print_log -y "[rpmfusion] " -b "skip :: " "already enabled"
else
    print_log -g "[rpmfusion] " -b "enable :: " "free + nonfree (fc${fedora_ver})"
    run sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
fi

# Enables $1 as a COPR project (project id, e.g. "owner/project") and prints
# its own status via return code rather than letting `set -e` (inherited
# from global_fn.sh) abort the script on a bare `dnf copr enable` failure --
# e.g. a chroot this COPR doesn't build at all for this architecture -- which
# would otherwise skip the actionable warning in verify_copr_pkg below.
enable_copr() {
    local copr="$1"
    if dnf copr list 2>/dev/null | grep -qi "${copr}"; then
        print_log -y "[copr] " -b "skip :: " "${copr} already enabled"
        return 0
    fi
    print_log -g "[copr] " -b "enable :: " "${copr}"
    run sudo dnf copr enable -y "${copr}"
}

# Checks that $2 (a package expected from COPR $3) actually resolves, given
# $1 = "0" if that COPR's enable_copr call above already failed. On failure,
# prints how to override via $4 (an env var name) instead of either a bare
# "no package" error deep into the real install, or silence.
verify_copr_pkg() {
    local enabled="$1" checkPkg="$2" copr="$3" overrideVar="$4"
    [ "${flg_DryRun}" -eq 1 ] && return 0
    if [ "${enabled}" != "0" ] || ! dnf --quiet repoquery "${checkPkg}" &>/dev/null; then
        print_log -err "[copr] " -crit "WARNING" "'${checkPkg}' is not available from ${copr} on this system ($(uname -m))"
        print_log -warn "copr" "Set ${overrideVar} to a COPR with confirmed builds for your architecture and re-run this script, e.g.:"
        print_log -warn "copr" "  ${overrideVar}=<owner>/<project> ./Scripts/enable_repos_fedora.sh"
        print_log -warn "copr" "Check https://copr.fedorainfracloud.org/coprs/ for whichever fork currently builds your architecture -- this changes over time."
        return 1
    fi
    return 0
}

hyprlandCoprDefault="solopasha/hyprland"
[ "$(uname -m)" = "aarch64" ] && hyprlandCoprDefault="lionheartp/Hyprland"
hyprlandCopr="${HYDE_FEDORA_HYPRLAND_COPR:-${hyprlandCoprDefault}}"
starshipCopr="${HYDE_FEDORA_STARSHIP_COPR:-atim/starship}"

hyprlandEnabled=0
enable_copr "${hyprlandCopr}" || hyprlandEnabled=1

starshipEnabled=0
enable_copr "${starshipCopr}" || starshipEnabled=1

print_log -g "[dnf] " -b "refresh :: " "package metadata"
run sudo dnf makecache || true

reposFailed=0
verify_copr_pkg "${hyprlandEnabled}" hyprland "${hyprlandCopr}" HYDE_FEDORA_HYPRLAND_COPR || reposFailed=1
verify_copr_pkg "${starshipEnabled}" starship "${starshipCopr}" HYDE_FEDORA_STARSHIP_COPR || reposFailed=1

if [ "${reposFailed}" -eq 1 ]; then
    exit 1
fi

print_log -g "[repos] " -b "complete :: " "RPM Fusion, ${hyprlandCopr}, and ${starshipCopr} COPRs ready"
