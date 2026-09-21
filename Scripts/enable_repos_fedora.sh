#!/usr/bin/env bash
# shellcheck disable=SC1091
#|---/ /+---------------------------------------------------+---/ /|#
#|--/ /-| Enable the RPM repos HyDE needs on Fedora / Asahi |--/ /-|#
#|-/ /--| Fedora / Fedora Asahi Remix port                  |--/ /-|#
#|/ /---+---------------------------------------------------+/ /---|#
#
# Arch's install_pre.sh reaches for pacman.conf and Chaotic-AUR here; Fedora
# has no AUR, so the equivalent is RPM Fusion (codecs, a handful of non-free
# bits) and a Hyprland-ecosystem COPR, which is where the packages in
# Scripts/dots/*.toml's `dnf = [...]` arrays marked "-- COPR" come from. Both
# are idempotent: re-running this after they're already enabled is a no-op.
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

hyprlandCoprDefault="solopasha/hyprland"
[ "$(uname -m)" = "aarch64" ] && hyprlandCoprDefault="lionheartp/Hyprland"
hyprlandCopr="${HYDE_FEDORA_HYPRLAND_COPR:-${hyprlandCoprDefault}}"

coprEnableFailed=0
if dnf copr list 2>/dev/null | grep -qi "${hyprlandCopr}"; then
    print_log -y "[copr] " -b "skip :: " "${hyprlandCopr} already enabled"
else
    print_log -g "[copr] " -b "enable :: " "${hyprlandCopr} (Hyprland ecosystem builds for Fedora)"
    # A chroot this COPR doesn't build (e.g. no aarch64 build at all) makes
    # `dnf copr enable` exit non-zero; under this script's `set -e` (inherited
    # from global_fn.sh) that would otherwise abort here and skip straight
    # past the actionable warning below, leaving only the raw dnf error.
    if ! run sudo dnf copr enable -y "${hyprlandCopr}"; then
        coprEnableFailed=1
    fi
fi

print_log -g "[dnf] " -b "refresh :: " "package metadata"
run sudo dnf makecache || true

# The COPR landscape above is not reliably verified for every architecture;
# catch it here with an actionable message instead of letting `hyprland` fail
# to resolve deep into the install (or, if the enable itself failed above,
# instead of stopping on a bare dnf error with no next step).
if [ "${flg_DryRun}" -ne 1 ] && { [ "${coprEnableFailed}" -eq 1 ] || ! dnf --quiet repoquery hyprland &>/dev/null; }; then
    print_log -err "[copr] " -crit "WARNING" "'hyprland' is not available from ${hyprlandCopr} on this system ($(uname -m))"
    print_log -warn "copr" "Set HYDE_FEDORA_HYPRLAND_COPR to a COPR with confirmed builds for your architecture and re-run this script, e.g.:"
    print_log -warn "copr" "  HYDE_FEDORA_HYPRLAND_COPR=lionheartp/Hyprland ./Scripts/enable_repos_fedora.sh"
    print_log -warn "copr" "Check https://copr.fedorainfracloud.org/coprs/ for whichever fork currently builds your architecture -- this changes over time."
    exit 1
fi

print_log -g "[repos] " -b "complete :: " "RPM Fusion and ${hyprlandCopr} COPR ready"
