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
# The Fedora Hyprland-on-COPR landscape churns and forks often, and aarch64
# (Asahi) coverage varies by fork and by day; solopasha/hyprland is the
# longest-standing one but its aarch64 builds are not guaranteed. Override
# HYDE_FEDORA_HYPRLAND_COPR to point at a different one (e.g. a fork known to
# build aarch64 today) without editing this script. See FEDORA-ASAHI.md.

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

hyprlandCopr="${HYDE_FEDORA_HYPRLAND_COPR:-solopasha/hyprland}"

if dnf copr list 2>/dev/null | grep -qi "${hyprlandCopr}"; then
    print_log -y "[copr] " -b "skip :: " "${hyprlandCopr} already enabled"
else
    print_log -g "[copr] " -b "enable :: " "${hyprlandCopr} (Hyprland ecosystem builds for Fedora)"
    run sudo dnf copr enable -y "${hyprlandCopr}"
fi

print_log -g "[dnf] " -b "refresh :: " "package metadata"
run sudo dnf makecache

# The COPR landscape above is not reliably verified for aarch64 (see the
# comment at the top of this file); catch it here with an actionable message
# instead of letting `hyprland` fail to resolve deep into the install.
if [ "${flg_DryRun}" -ne 1 ] && [ "$(uname -m)" = "aarch64" ]; then
    if ! dnf --quiet repoquery hyprland &>/dev/null; then
        print_log -err "[copr] " -crit "WARNING" "'hyprland' did not resolve from ${hyprlandCopr} on aarch64"
        print_log -warn "copr" "Set HYDE_FEDORA_HYPRLAND_COPR to a COPR with confirmed aarch64 builds and re-run this script, e.g.:"
        print_log -warn "copr" "  HYDE_FEDORA_HYPRLAND_COPR=lionheartp/Hyprland ./Scripts/enable_repos_fedora.sh"
        print_log -warn "copr" "Check https://copr.fedorainfracloud.org/coprs/ for whichever fork currently builds aarch64 -- this changes over time."
    fi
fi

print_log -g "[repos] " -b "complete :: " "RPM Fusion and ${hyprlandCopr} COPR ready"
