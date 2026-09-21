#!/usr/bin/env bash
# shellcheck disable=SC1091
#|---/ /+---------------------------------------------------+---/ /|#
#|--/ /-| Enable the RPM repos HyDE needs on Fedora / Asahi |--/ /-|#
#|-/ /--| Fedora / Fedora Asahi Remix port                  |--/ /-|#
#|/ /---+---------------------------------------------------+/ /---|#
#
# Arch's install_pre.sh reaches for pacman.conf and Chaotic-AUR here; Fedora
# has no AUR, so the equivalent is RPM Fusion (codecs, a handful of non-free
# bits) and the solopasha/hyprland COPR, which is where the Hyprland
# ecosystem packages in Scripts/dots/*.toml's `dnf = [...]` arrays come from.
# Both are idempotent: re-running this after they're already enabled is a
# no-op.

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

if dnf copr list 2>/dev/null | grep -qi "solopasha/hyprland"; then
    print_log -y "[copr] " -b "skip :: " "solopasha/hyprland already enabled"
else
    print_log -g "[copr] " -b "enable :: " "solopasha/hyprland (Hyprland ecosystem builds for Fedora)"
    run sudo dnf copr enable -y solopasha/hyprland
fi

print_log -g "[dnf] " -b "refresh :: " "package metadata"
run sudo dnf makecache

print_log -g "[repos] " -b "complete :: " "RPM Fusion and solopasha/hyprland COPR ready"
