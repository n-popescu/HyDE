# HyDE on Fedora / Fedora Asahi Remix

HyDE's install scripts were written for Arch Linux and lean on `pacman` and
AUR helpers throughout. This document describes the `dnf`-based port that
lets the same scripts run on **Fedora** and, in particular, on
**[Fedora Asahi Remix](https://asahilinux.org/fedora/)** — the Fedora spin
for Apple Silicon Macs.

This is a community-maintained port layered on top of the upstream Arch
scripts, kept additive: nothing here changes behavior on Arch. It is
best-effort and package names were mapped by hand from the Arch side; if
something is wrong or missing, please open an issue or a PR.

## What changed

- `Scripts/global_fn.sh` gained `is_fedora` / `is_asahi` detection (read from
  `/etc/os-release`), and `pkg_installed`/`nvidia_detect` now behave
  correctly on Fedora instead of assuming `pacman`.
- `Scripts/install.sh` skips the AUR-helper prompts on Fedora and writes the
  transient dependency manifests it builds at install/restore time with a
  `dnf = [...]` key instead of `pacman = [...]`.
- `Scripts/install_pre.sh` and `Scripts/install_aur.sh` call the new
  `Scripts/enable_repos_fedora.sh` on Fedora instead of touching
  `pacman.conf` / Chaotic-AUR.
- `Scripts/enable_repos_fedora.sh` is the Fedora equivalent of
  `Scripts/chaotic_aur.sh`: it enables [RPM Fusion](https://rpmfusion.org/)
  (free + nonfree) and a COPR that packages most of the Hyprland ecosystem
  for Fedora — `solopasha/hyprland` on x86_64,
  [`lionheartp/Hyprland`](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/)
  on aarch64 (see the aarch64 section below for why they differ), override
  with `HYDE_FEDORA_HYPRLAND_COPR` — then refreshes `dnf`'s metadata cache.
  It's idempotent — safe to re-run.
- The per-app manifests under `Scripts/dots/*.toml` and the aggregate
  `Scripts/dots/deps.toml` now carry a `dnf = [...]` array alongside the
  existing `pacman = [...]` one, wherever Fedora has an equivalent package.
  This works because HyDE's dot-deployment tool (`deez-dots`) already reads a
  `[[global.package_managers]]` table with a `dnf` entry
  (`Scripts/dots-groups/core.toml`, `extra.toml`) and resolves dependencies
  by whichever manager it detects — the Fedora support was already half
  built into the manifest format, this port fills in the missing `dnf` keys.

Nothing pacman/AUR-specific was removed; a Fedora check gates the new paths,
so Arch installs are unaffected.

## Package sourcing on Fedora

| Source | Used for |
| --- | --- |
| Fedora's own repos | Most base packages (kitty, dunst, rofi, firefox, pipewire, NetworkManager, sddm, qt5ct/qt6ct, kvantum, fastfetch, lsd, zsh/fish, SwayNotificationCenter, ...) |
| RPM Fusion | Codecs and a handful of non-free packages |
| Hyprland-ecosystem COPR (`solopasha/hyprland` on x86_64, `lionheartp/Hyprland` on aarch64 — see below) | The Hyprland ecosystem itself: hyprland, hyprlock, hypridle, hyprpicker, hyprsunset, xdg-desktop-portal-hyprland, hyprpolkitagent, wlogout, awww, cliphist, nwg-look, and related tools |
| `atim/starship` COPR | `starship` — dropped from Fedora's own repos after Fedora 36, needed unconditionally by both shells |
| Flathub (`flatpak`) | Apps without a good native path — VS Code, VSCodium, Spotify |
| Manual install | Tools with no confirmed Fedora/COPR package (see below) |

`Scripts/enable_repos_fedora.sh` enables both COPRs (RPM Fusion too), then
verifies `hyprland` and `starship` actually resolve before continuing —
confirmed on real hardware to catch a COPR silently missing a given
architecture rather than fail deep into the real install.

**Not auto-installed**, confirmed absent from both the Hyprland-ecosystem
COPR and Fedora's own repos on real hardware — installing every unresolved
name in one `dnf install` call fails the *whole* batch (dnf, unlike
pacman/apt, won't partially install the rest), so these were pulled out of
`Scripts/dots/deps.toml`'s `dnf` array entirely rather than risk blocking
everything else in it:

| Package | Where to get it |
| --- | --- |
| `satty` | COPR (community, unverified): `mineiro/satty-rpms`, or `cargo install satty` |
| `wl-clip-persist` | COPR (community, unverified): `leloubil/wl-clip-persist` |
| `nwg-displays` | COPR (community, unverified), e.g. `aeiro/nwg-shell` — part of the nwg-shell family, several forks exist |
| `hyprquery` | No known Fedora/COPR package; build from source: [HyDE-Project/hyprquery](https://github.com/HyDE-Project/hyprquery) |
| `libinput-gestures` | Not packaged for Fedora at all; `pip install --user libinput-gestures` or clone upstream |

## aarch64 (Apple Silicon) compatibility

Short answer: most of it, confirmed; the Hyprland-ecosystem COPR is the one
real open question, and the installer now checks for it rather than failing
silently.

- **Fedora's own repos and RPM Fusion**: aarch64 is a primary Fedora
  architecture and RPM Fusion builds for it too, so everything sourced from
  those two rows of the table above (the large majority of the dependency
  list) is aarch64-native as a matter of course — no per-package check
  needed.
- **Flathub** (`com.visualstudio.code`, `com.vscodium.codium`,
  `com.spotify.Client`): all three publish aarch64 builds on Flathub; Flatpak
  installs the matching architecture automatically.
- **The Hyprland-ecosystem COPR**: this is the actual risk, and it's a
  confirmed one, not just a theoretical one. The Fedora Hyprland-on-COPR
  scene forks and churns constantly. `solopasha/hyprland` — the
  longest-standing one, and this port's default on x86_64 — has **no
  aarch64 chroot at all**: `dnf copr enable` on real Fedora Asahi Remix
  hardware fails immediately with `chroot not found in the given project
  ... available chroots: fedora-rawhide-x86_64`. On aarch64,
  `enable_repos_fedora.sh` therefore defaults to `lionheartp/Hyprland`
  instead, a fork reported to build both aarch64 and x86_64 for Fedora 44 —
  but community COPRs like this come and go, so treat that as "the current
  best guess," not a permanent answer. The script reads
  `HYDE_FEDORA_HYPRLAND_COPR` to override either default, and now exits
  with an actionable message (rather than a bare dnf error, or silently
  continuing into a confusing failure later) if `hyprland` still can't be
  resolved after enabling it. If you hit this, check
  <https://copr.fedorainfracloud.org/coprs/> for whichever fork currently
  builds your architecture and re-run with
  `HYDE_FEDORA_HYPRLAND_COPR=<owner>/<project> ./Scripts/enable_repos_fedora.sh`.
- **Manual-install items** (`libinput-gestures`): it's pure Python/shell, so
  it runs fine on aarch64; it's just not packaged for Fedora at all,
  independent of architecture.

## Fedora Asahi Remix specifics

- **No NVIDIA path.** Apple Silicon has no discrete GPU slot, so
  `nvidia_detect` short-circuits to "no NVIDIA" on Asahi and the installer
  never touches DKMS, `nvidia_drm.modeset`, or bootloader kernel parameters
  for it.
- **No GRUB / systemd-boot config rewrite.** Asahi's boot flow (`m1n1` +
  `u-boot`) isn't either of those, so the bootloader steps in
  `Scripts/install_pre.sh` naturally no-op (they're already gated on
  `pkg_installed grub` / a `systemd-boot` check).
- The Asahi GPU driver (Mesa's `asahi` driver) ships in Fedora Asahi Remix
  already — no extra driver package is needed for Hyprland to run.

## Running it

```shell
sudo dnf install -y git
git clone --depth 1 https://github.com/HyDE-Project/HyDE ~/HyDE
cd ~/HyDE/Scripts
./install.sh
```

The flow is otherwise identical to the Arch instructions in the main
[README](./README.md#installation): `-p` for pre-install only, `-r` to
restore configs, `-irs` for a full install, etc.

There's no single Fedora equivalent of Arch's `base-devel` group that also
covers headers -- Fedora always splits headers into a `-devel` package per
library, with no meta-package that bundles them all the way `base-devel`
does on Arch. `Scripts/dots/deps.toml` declares the exact toolchain/headers
this install actually needs (`gcc`, `make`, `lua-devel`, `openssl-devel`,
...) so you shouldn't need anything extra for HyDE itself. If you expect to
build other things from source later (e.g. one of the manual-install tools
below), it's worth running the closer toolchain analog once up front:

```shell
sudo dnf group install "Development Tools"
```

## Keeping this port in sync

Fedora/Asahi support here is derived from the upstream Arch scripts and
package manifests, so it drifts whenever those change. A scheduled sync
routine periodically diffs `master` against the last commit it reviewed and
ports any new/changed dependency lists or install-script logic that need a
Fedora counterpart, pushing the result to this port's branch. If you notice
the port is stale, that routine (or its next run) is the mechanism that
should catch up — it is not a substitute for filing an issue if something is
actually broken.
