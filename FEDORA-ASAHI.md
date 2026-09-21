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
  (free + nonfree) and the
  [`solopasha/hyprland`](https://copr.fedorainfracloud.org/coprs/solopasha/hyprland/)
  COPR, which packages most of the Hyprland ecosystem for Fedora, then
  refreshes `dnf`'s metadata cache. It's idempotent — safe to re-run.
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
| Fedora's own repos | Most base packages (kitty, dunst, rofi, firefox, pipewire, NetworkManager, sddm, qt5ct/qt6ct, kvantum, fastfetch, lsd, zsh/fish/starship, ...) |
| RPM Fusion | Codecs and a handful of non-free packages |
| `solopasha/hyprland` COPR | The Hyprland ecosystem itself: hyprland, hyprlock, hypridle, hyprpicker, hyprsunset, xdg-desktop-portal-hyprland, hyprpolkitagent, wlogout, and related tools |
| Flathub (`flatpak`) | Apps without a good native path — VS Code, VSCodium, Spotify |
| Manual install | A few AUR-only tools with no Fedora/COPR equivalent found yet (e.g. `libinput-gestures`) |

Packages marked `-- COPR` in `Scripts/dots/deps.toml` are expected to come
from whichever COPR `Scripts/enable_repos_fedora.sh` enables (default
`solopasha/hyprland`); a few (`awww`, `wl-clip-persist`, `nwg-look`,
`nwg-displays`, `hyprquery`) are noted as unverified because their presence
in that COPR fluctuates upstream — if `dnf install` can't find one, check the
COPR's package list first, then fall back to building from source.

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
- **The Hyprland-ecosystem COPR**: this is the actual risk. The Fedora
  Hyprland-on-COPR scene forks and churns constantly, and which fork
  currently builds aarch64 changes over time — `solopasha/hyprland` (this
  port's default) has not been confirmed to build aarch64 at all;
  `lionheartp/Hyprland` claimed aarch64 + x86_64 coverage for Fedora 43/44 at
  the time of writing, but community repos like this come and go. Rather
  than hardcode a specific fork as "the" answer, `enable_repos_fedora.sh`
  reads `HYDE_FEDORA_HYPRLAND_COPR` (defaulting to `solopasha/hyprland`) and,
  on aarch64, runs a `dnf repoquery hyprland` check after enabling it —
  if `hyprland` doesn't resolve, it prints how to point at a different COPR
  instead of letting the install fail later with a confusing "no package"
  error. If you hit this, check
  <https://copr.fedorainfracloud.org/coprs/> for whichever fork currently
  builds aarch64 and re-run with `HYDE_FEDORA_HYPRLAND_COPR=<owner>/<project>`.
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

## Keeping this port in sync

Fedora/Asahi support here is derived from the upstream Arch scripts and
package manifests, so it drifts whenever those change. A scheduled sync
routine periodically diffs `master` against the last commit it reviewed and
ports any new/changed dependency lists or install-script logic that need a
Fedora counterpart, pushing the result to this port's branch. If you notice
the port is stale, that routine (or its next run) is the mechanism that
should catch up — it is not a substitute for filing an issue if something is
actually broken.
