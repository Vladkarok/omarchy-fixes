# Remmina on Omarchy

RDP against a Wayland/Hyprland host on a fractionally scaled panel (eDP-2, 2560x1600,
`scale=1.6`). Two problems worth writing down: Alt+Tab never reaching the guest, and a
blurry, oversized remote desktop.

## Alt+Tab (and other guest shortcuts)

Not a Remmina problem. Omarchy binds `ALT, TAB` to `cyclenext`
(`~/.local/share/omarchy/default/hypr/bindings/tiling.conf`), and Hyprland consumes a
bound key before the client ever sees it — no keyboard grab, on X11 or Wayland, can win
against that.

Fix is a Hyprland passthrough submap, which disables every bind while active. See the
block at the end of [../hypr/bindings.conf](../hypr/bindings.conf):

```
bind = SUPER, F12, submap, passthrough
submap = passthrough
bind = SUPER, F12, submap, reset
submap = reset
```

`SUPER + F12` toggles it both ways; `hyprctl submap` shows the current state.

Only one bind per key fires inside a submap. Adding a second one (a `notify-send`, say)
on the same key shadows the `submap, reset` and strands you in passthrough with every
hotkey dead.

## Sharpness: native Wayland with a local patch (since 2026-10-12)

The panel now runs at integer scale 2, and Remmina runs on native Wayland from a locally patched package (`PKGBUILD` + `remmina-hidpi-dynres.patch` here, built as `1:1.4.43-3.1`). Stock Remmina's dynamic resolution asks the server for the logical window size, so GTK doubles it: clean but huge. The patch requests logical size × GTK scale factor and draws it back at 1/factor, an exact pixel copy, and hands the remote pointer to GDK at the same scale. It fills the window at any size and in fullscreen. X11 is no longer needed, which also avoids Hyprland 0.56.2 never unhiding the cursor over XWayland windows.

Rebuild after every Remmina update: `cd remmina && makepkg -df` (the `-d` skips the unneeded gobject-introspection makedepend), then `pacman -U` the result.

## Old: run it on XWayland, not Wayland (scale 1.6 era)

Counterintuitive on this setup, but measured: XWayland is ~9x sharper.

| launch | sharpness (variance of Laplacian, same crop) |
|---|---|
| Wayland native, `GDK_SCALE=1` | 277 |
| XWayland, `GDK_SCALE=1 GDK_DPI_SCALE=1` | 2520 |

Omarchy sets `xwayland { force_zero_scaling = true }`
(`~/.local/share/omarchy/default/hypr/envs.conf`), so XWayland surfaces render at real
device pixels and the compositor never upscales them — 1:1. Remmina on native Wayland
gets the opposite: GTK3 has no `wp_fractional_scale_v1` support (GTK4 4.14+ only), so it
draws at an integer scale and the compositor resamples down to 1.6.

Two traps that produce a huge, soft picture:

- `env = GDK_SCALE,2` in `hypr/monitors.conf` is inherited by everything launched from a
  shell or the app launcher. Combined with compositor scaling it applies scale twice.
  The desktop file below pins `GDK_SCALE=1`.
- Passing `/scale-desktop:` and `/scale-device:` in the profile's extra FreeRDP
  arguments duplicates what `rdp_desktopScaleFactor` / `rdp_deviceScaleFactor` already
  send, and FreeRDP then ignores both. Leave `freerdp_params` empty. RDP only accepts
  100, 140 and 180 — intermediate values are silently dropped.

Size in the guest belongs to `rdp_desktopScaleFactor` (140 here): real Windows DPI, so
it stays pixel-sharp, unlike stretching the remote framebuffer. Windows applies it at
session start — a persisted session needs a logoff, not a disconnect.

## Tray icon: a missing icon theme, not a Remmina bug

Remmina's tray applet (`remmina -i`) is the only tray item here that publishes an
*IconName* (`org.remmina.Remmina-status`) instead of a raw pixmap, so it is the first
thing to break when the icon theme cannot be resolved. Everything else in the tray kept
working, which made it look Remmina-specific:

```
omarchy-shell: WARN: Could not load icon "org.remmina.Remmina-status" ... from request
```

The theme in use pointed at `Yaru-gray`, which `yaru-icon-theme` does not ship — the
name comes from Omarchy's `vantablack` theme (`white` has the same defect spelled
`Yaru-grey`) and travels into any theme copied from it. `omarchy-theme-set-gnome` only
falls back when the `icons.theme` file is *missing*; it never checks that the name
resolves. Upstream: [omacom/omarchy#7203](https://github.com/omacom/omarchy/issues/7203).

Name the real theme in the theme that is actually in use:

```bash
echo Yaru-dark > ~/.config/omarchy/themes/neutral-dark/icons.theme
gsettings set org.gnome.desktop.interface icon-theme Yaru-dark
```

and alias the broken name once, so Omarchy's own themes stop mattering:

```bash
ln -sfn /usr/share/icons/Yaru-dark ~/.local/share/icons/Yaru-gray
```

`~/.local/share/icons` precedes `/usr/share/icons` in the XDG search path, so this covers
`vantablack` without touching the `omarchy-dev` package, which would overwrite an edit on
the next update. `Yaru-dark` ships `22x22/panel/org.remmina.Remmina-status.svg` as a white
glyph, which is what the dark bar wants.

Restoring app-brand colours is not the monochrome look Vantablack intends — that half of
the upstream issue is a design decision, not something to fix here.

## Files

- `org.remmina.Remmina.desktop` → `~/.local/share/applications/` — pins the launch
  environment (`GDK_BACKEND=x11 GDK_SCALE=1 GDK_DPI_SCALE=1 GTK_THEME=Adwaita-dark`)
- `remmina.pref.example` → `~/.config/remmina/remmina.pref` — `secret` and
  `unlock_password` blanked
- `rdp-profile.example.remmina` → `~/.local/share/remmina/` — credentials, host and
  domain blanked

Remmina rewrites both files when it exits, so edit them with Remmina closed or the
change is lost. `keyboard_grab` in particular is better toggled from the session toolbar
than from the file.
