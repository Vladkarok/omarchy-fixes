# agterm-linux Install Notes

Last updated: 2026-11-12

[agterm-linux](https://github.com/melonamin/agterm-linux) (`linux-port` branch) is a
Swift/GTK4 terminal that groups sessions into workspaces, with an `agtermctl` control
socket CLI aimed at driving several coding agents at once.

Installed version: **linux-v0.19.0**

## Why the Tarball

There is no AUR package. Upstream publishes `.deb`, `.rpm`, `.AppImage`, and a
relocatable `.tar.gz`, all built on Ubuntu 24.04 x86_64. DEB/RPM are useless on Arch,
and building from source needs Swift 6.3.2 + Zig 0.15.2.

The tarball beat the AppImage here because:

- It bundles only the Swift runtime and libghostty, taking GTK4/libadwaita from the host,
  so the app uses the real Omarchy GTK theme, cursor, portals, and input method. A
  bundled GTK4 stack is the usual source of theme and IME breakage.
- AppImage mounts are sandbox-local, so agterm cannot create a persistent
  `~/.local/bin/agtermctl` from one. The tarball can.
- 53 MB vs 79 MB, and no FUSE mount on launch.

Host deps all satisfied: glibc 2.44 (needs >= 2.39), gtk4 4.22.4, libadwaita 1.9.2,
libepoxy 1.5.10. `ldd` against the bundled `lib/` resolves everything.

## Installed Files

- `~/.local/share/agterm/agterm-linux/` — extracted payload (not in this repo)
- `~/.local/bin/agterm` -> `.../agterm-linux/bin/agterm-linux`
- `~/.local/bin/agtermctl` -> `.../agterm-linux/bin/agtermctl`
- `~/.local/share/icons/hicolor/256x256/apps/io.github.melonamin.agterm.png`
  (the shipped pixmap is 1254x1254, resized with `magick`)
- `~/.local/share/pixmaps/io.github.melonamin.agterm.png` (full-size fallback copy)
- `~/.local/share/applications/io.github.melonamin.agterm.desktop`

The repo copy of the desktop entry is `agterm/io.github.melonamin.agterm.desktop`.

Both `bin/` entries are shell wrappers that resolve `readlink -f "$0"` and set
`LD_LIBRARY_PATH`, so symlinking them into `~/.local/bin` works as-is.

## Desktop Entry Fixes

Two changes from the desktop file shipped inside the tarball:

- `Exec=agterm-linux` -> `Exec=agterm`, matching the symlink name on PATH.
- `StartupWMClass=io.github.melonamin.agterm` -> `StartupWMClass=agterm-linux.bin`.
  The shipped value is wrong for the tarball layout: the app does not set its own
  Wayland app_id, so Hyprland reports the argv[0] basename. Verified with
  `hyprctl clients -j`. Use `agterm-linux.bin` for any Hyprland window rule too.

## Do Not Add index.theme to the User hicolor Dir

`gtk4-update-icon-cache` refuses to build a cache for `~/.local/share/icons/hicolor`
("generated cache was invalid"), so there is no `icon-theme.cache` there. That is
harmless and needs no fix — GTK scans the directory directly.

Do **not** "fix" it by dropping an `index.theme` into `~/.local/share/icons/hicolor/`.
Doing that broke every icon in agterm — the whole UI rendered as red `image-missing`
placeholders. GTK searches user data dirs before system ones, so a user-level
`hicolor/index.theme` shadows `/usr/share/icons/hicolor/index.theme`; the shadowing
copy declares only the handful of directories that exist locally, which truncates the
fallback chain that `Papirus-Dark` (`Inherits=breeze-dark,hicolor`) terminates in.
Every symbolic icon then fails to resolve.

Confirmed by A/B screenshot: file absent = icons render, file present = red boxes.
The user hicolor dir now contains only size subdirectories and no `index.theme`.

Icon lookup verified via `Gtk.IconTheme.has_icon` under the active `Papirus-Dark`
theme: `io.github.melonamin.agterm`, `list-add-symbolic`, and `view-more-symbolic`
all resolve.

## Verification

```sh
gh attestation verify agterm-linux-v0.19.0-x86_64.tar.gz --repo melonamin/agterm-linux
```

Checksum from the release `SHA256SUMS` and the GitHub build-provenance attestation both
passed before extraction. `agtermctl tree --json` returns the live session tree while
agterm is running.

## Upgrades

Nothing owns this — no package manager. To upgrade: download the new tarball, verify
checksum and attestation, then replace `~/.local/share/agterm/agterm-linux/`. The
symlinks and desktop entry survive.

Re-check the AUR occasionally; if `agterm-linux` or `agterm-bin` appears, switch to it.

## Agent integrations

The agterm agent-status hooks and the `agterm` skill (both offered in Preferences -> Integrations) are installed. The hook scripts live in `~/.config/agterm/agent-status/`; Claude Code calls them from `~/.claude/settings.json`, and Codex from `~/.codex/hooks.json` and `~/.codex/config.toml`. The skill is `~/.agents/skills/agterm/`, linked as `~/.claude/skills/agterm` since 2026-09-02.
