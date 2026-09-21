# Customization Inventory (pre-Omarchy-4.0)

Snapshot taken **2026-07-30** against **Omarchy 3.8.4** / Hyprland 0.56.1.

## Purpose

The plan is to upgrade to Omarchy 4.0, **accept the stock defaults everywhere**, live
with them, and then re-add only the tweaks that are actually missed. This file is the
reference for that second step: what was customized, what the value was, and *why* it
existed — so each one can be judged on merit instead of restored blindly.

Entries are grouped by how quickly the absence will be noticed. Work top-down: Tier 1
before the first real session, Tier 2 within a day or two, Tier 3 only when something
feels wrong.

Where the "why" is recorded fact (git history, prior debugging) it says so. Where it is
inferred from the config alone, it is marked *(inferred)* — worth re-deciding rather
than assuming.

**One structural change to expect in v4:** Hyprland config moves from `.conf` to Lua.
`hyprland.conf` becomes `hyprland.lua`, `source =` becomes `require()`, and bindings
use a new DSL (`o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })` instead of
`bindd = SUPER SHIFT, T, ...`). It is all-or-nothing — a `.lua` entry point cannot
source old `.conf` files. So every Hyprland entry below needs *translating*, not
copying. Hyprland 0.56.1 already supports this natively, so it can be trialled before
the upgrade if wanted.

---

## Tier 1 — restore before the first working session

These are hardware, language, or workflow blockers. Without them the machine is
actively harder to use.

### Ukrainian keyboard layout

```
# hypr/input.conf
kb_layout = us,ua
kb_options = compose:caps,grp:alt_shift_toggle
```

Stock has no second layout. `grp:alt_shift_toggle` puts layout switching on
Alt+Shift. Note `compose:caps` is upstream's default and worth keeping.

**Why:** daily Ukrainian typing. Non-negotiable.

### kitty: re-send Ctrl+V as latin

```
# kitty/kitty.conf
map ctrl+v send_key ctrl+v
```

**Why:** recorded fact — commit `7c06e7d`. On the UA layout, kitty-protocol TUIs
(codex, and others using the kitty keyboard protocol) receive `Ctrl+м` instead of
`Ctrl+V` and silently miss paste. This is a genuine bug workaround, not a preference.
Re-apply as soon as kitty is in use with the UA layout.

### hyprlock layout indicator

A `label` block showing `$LAYOUT[EN,UA]` at `position = 0, -70`, with
`onclick = hyprctl switchxkblayout all next`.

**Why:** the lock screen gives no other feedback about which layout is active, so a
password typed on the wrong layout fails with no explanation. Directly related to the
long-standing numpad/NumLock trouble on this machine — see the
`hyprland-per-device-numlock-resume` notes. **Still unsolved**; the compositor patch
was tried and abandoned.

### `~/.local/bin` ahead of Omarchy on PATH

```sh
# uwsm/env
export PATH=$HOME/.local/bin:$OMARCHY_PATH/bin/:$PATH
```

Stock puts `$OMARCHY_PATH/bin` first and `~/.local/bin` last.

**Why:** this single line is what makes the local forks take effect —
`omarchy-cmd-screenshot` and `omarchy-brightness-display` in `~/.local/bin` shadow the
Omarchy-shipped versions. **If this is not restored, those forks silently do nothing**
and it will look like the forks themselves broke. Restore it at the same time as any
`~/.local/bin` override, or not at all.

### Brightness on `nvidia_wmi_ec_backlight`

Waybar `custom/brightness` module plus the `omarchy-brightness-display` fork, all
passing the `nvidia_wmi_ec_backlight` backlight device explicitly.

**Why:** recorded fact — several commits (`ca93651`, `23f21a2`, `1572955`) established
a hardware-based brightness floor at 5% for this specific panel. Stock brightness
handling was wrong on this hardware. See the repo README brightness section.

### NVIDIA environment

```
# hypr/hyprland.conf (inline)
env = NVD_BACKEND,direct
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
# LIBVA_DRIVER_NAME deliberately NOT set globally — let apps auto-detect per GPU
```

**Why:** the comment in the config is explicit that a global `LIBVA_DRIVER_NAME` was
removed on purpose. Preserve that decision — re-adding it would regress hybrid-GPU
video decode.

### Display scaling

```
# hypr/monitors.conf
env = GDK_SCALE,2
monitor=,preferred,auto,auto
```

**Why:** retina-class panel. Everything is unreadable at 1x. Check what v4's default
detection does first — it may now handle this automatically.

---

## Tier 2 — quality of life, restore when missed

### Waybar bar layout

The most heavily rebuilt piece. All backing scripts already live in this repo with
install instructions in the README — re-add modules one at a time rather than
wholesale, and see which are genuinely missed.

| module | replaces | what it adds |
|---|---|---|
| `custom/cpu` | built-in `cpu` | usage % beside the icon, per-core hover, load graphs, warm/hot/critical colors |
| `custom/volume` | `pulseaudio` | coarse level glyphs, exact 0% and muted handling, `pamixer` scroll |
| `custom/brightness` | — | see Tier 1 |
| `memory` | — | built-in module, `{percentage}%`, warning 70 / critical 85 |
| `custom/language` | — | current xkb layout, click cycles |
| `custom/screen-keyboard` | — | `wvkbd` on-screen keyboard toggle |
| `custom/calendar` | — | GTK calendar popup |

Also: `clock` at `interval: 1` with seconds (`{:L%A %H:%M:%S}`), module `spacing`
17 → 12, `custom/update` interval 21600 → 3600, and matching CSS blocks (margins, plus
color states `#custom-cpu.warm/.hot/.critical` and `#memory.warning/.critical`).

**Two notes before restoring any of it:**

1. **`custom/calendar` may be redundant.** The reason for this whole review. As of the
   public v4 alpha there is still no built-in calendar widget — but check the shipped
   4.0 release before re-adding, since a built-in one was the expectation.
2. **v4 splits the clock** into `clock#horizontal` / `clock#vertical` for the new
   vertical-bar support. The seconds customization must be applied to the *horizontal*
   variant, not a plain `clock` key, or it will be ignored.

### Idle and lock timings

|  | stock 3.8.4 | customized |
|---|---|---|
| screensaver | 2.5 min | **disabled** |
| display off | — | 30 min |
| lock | 5 min | 45 min |

**Why:** *(inferred)* the stock timings are aggressive for a desktop that sits with
long-running work visible. The screensaver was dropped entirely rather than retimed.

**Do not restore** the `hyprctl reload` that was in `after_sleep_cmd` — it was part of
the abandoned NumLock-on-resume fix and does nothing useful.

### Font: CaskaydiaMono

`CaskaydiaMono Nerd Font` replaces `JetBrainsMono Nerd Font` in **kitty, alacritty,
ghostty, swayosd, hyprlock** — all five must change together or the desktop looks
inconsistent. kitty additionally at `font_size 15.0` (stock 9.0).

**Why:** *(inferred)* personal preference. A good candidate for genuinely re-deciding
— v4 ships a different default and it may be fine.

### kitty as default terminal

`xdg-terminals.list` → `kitty.desktop` (stock: `Alacritty.desktop`), plus
`window_padding_height 14`, `copy_on_select yes`, `single_instance yes`,
`show_window_resize_notification no`, `notify_on_cmd_finish invisible 3.0`,
`cursor_shape block`, `map F11 toggle_fullscreen`.

F11-to-fullscreen was also added to alacritty and ghostty, so it is clearly a wanted
cross-terminal habit.

### Window rules (`hypr/windows.conf` — user-created, no upstream equivalent)

**Global defaults** (added 2026-07-30), at the top of the file:

```
windowrule = float on, match:class .*
windowrule = opacity 1 1, match:class .*
```

New windows open **floating** rather than tiled, and all transparency is off. The
opacity rule overrides Omarchy's `opacity 0.985 0.96`, which is applied via a
`default-opacity` tag in `default/hypr/windows.conf` — not via `decoration:*_opacity`,
which was already `1.0`. It also overrides the per-app browser rules
(`opacity 1.0 0.985`).

**Ordering is load-bearing:** Hyprland applies matching rules in sequence, so the
blanket `float on` must stay *above* the per-app `tile on` rules below it. That is what
keeps the autostart chat apps tiled while everything else floats. Preserve this order
when porting to v4.

Then about 30 per-app rules, in three groups:

- **Chat apps pinned to workspaces**, tiled: Discord/Vesktop/WebCord and Telegram → ws 2;
  Whatsie, WhatsApp Desktop → ws 1; Viber → ws 2.
- **Gaming**: Last War (both by title and via `steam_proton`) → ws 5; its auxiliary
  empty-title window and xclicker → ws 15; `no_blur`, `no_shadow`, `opacity 1.0` on
  `steam_proton` for performance.
- Commented-out attempts to hide the Last War launcher that respawns and cannot be closed.

**Why:** these encode real per-app class names discovered by trial and error (e.g.
Whatsie's actual class is `com.ktechpit.whatsie`, not anything guessable). That
research is the valuable part — keep the file even if the layout choices change.

**Telegram group fix** (added 2026-08-05) — re-apply this one rather than
re-deciding it, it fixes a real bug:

```
windowrule = group barred, match:class ^(org\.telegram\.desktop|telegram-desktop|TelegramDesktop)$
```

Telegram's image viewer is a **separate window with the same class** as the chat
window, so the `tile on` rule above matches it and it opens tiled. Hyprland's
`group:auto_group = 1` (the default) then absorbs any new tiled window into the
focused group. Fullscreen a picture and close it, and the fullscreen state is
left on the surviving group member — the chat window looks stuck in Super+F
until you toggle it off. It fires even when the group holds only Telegram,
because the viewer briefly makes it a two-window group.

Verified two ways: `barred` stops the viewer joining the group, and Super+G
still groups Telegram by hand, so the grouping workflow is unaffected.

Upstream status as of 2026-08-05: **not fixed**. Neither Omarchy 3.8.4 nor the
4.0 alpha sets `auto_group`, and neither uses `barred` anywhere — the shipped
`apps/telegram.{conf,lua}` only sets `focus_on_activate = false`, for an
unrelated problem. The underlying defect (fullscreen surviving on the remaining
group member) is Hyprland's, not Omarchy's, so expect to keep carrying this.

For the v4 port this becomes roughly
`o.window("org.telegram.desktop", { group = "barred" })` — check the spelling
against `default/hypr/helpers.lua`, that form is unverified.

**Telegram viewer float/fit** (added 2026-08-05) — cosmetic, re-add only if the
tiled viewer bothers you:

```
windowrule = float on,      ... match:title ^(Media viewer)$
windowrule = size 1440 900, ... match:title ^(Media viewer)$
windowrule = center on,     ... match:title ^(Media viewer)$
```

Makes the image viewer open floating, centred, at 90% of the screen instead of
tiling into the layout. Matched on `title` because the viewer shares the chat
window's class — `Media viewer` is the **English-UI** title, so the rules stop
matching if the Telegram interface language is changed.

Two things worth carrying forward:

- **Percentages do not work.** `size 90% 90%` is silently ignored by Hyprland
  0.56.1 under the `match:` rule syntax; only absolute pixels apply. Verified by
  A/B — `50% 50%` left a probe window at its own size, `1440 900` applied
  exactly. So `1440 900` is tied to this display's 1600x1000 logical area
  (2560x1600 @ scale 1.6) and needs recalculating for another monitor.
- **Do not test window sizing with kitty.** Its `remember_window_size` default
  makes it reopen at its last size regardless of the rule, which looks exactly
  like a working rule and wasted a while here. Use a neutral window, or pass
  `-o remember_window_size=no`.

### Autostart (`hypr/autostart.conf`)

Six chat apps launched with `sleep 3` onto silent workspaces 1 and 2, plus
`xsettingsd` and `udiskie -aNT` (auto-mount for NTFS/Windows drives).

**Why:** the comment is explicit — the 3s delay exists because the apps race the
system tray and lose their tray icon if started too early. Keep the delay if the
autostarts come back.

### Extra keybindings

```
SUPER + SHIFT + T   Activity (btop)
SUPER + period      Emoji picker (emote)
SUPER + ALT + B     Next wallpaper
SUPER + ALT + K     Toggle screen keyboard
SUPER + F12         Toggle Hyprland passthrough submap (all binds off, for RDP/VMs)
```

Also `$terminal` / `$browser` variables, a changed Tmux binding (`tmux new` rather
than `tmux attach || tmux new -s Work`), YouTube switched to launch-or-focus, and
Google Photos + Typora bindings removed.

**Note:** v4 replaces `bindd =` with `o.bind("SUPER + SHIFT + T", "Activity", {...})`.
These need translating, not copying.

---

### Remmina RDP

Passthrough submap in `hypr/bindings.conf` (guest never sees Alt+Tab otherwise — Omarchy
binds it to `cyclenext`), plus a `~/.local/share/applications/` desktop file pinning
`GDK_BACKEND=x11 GDK_SCALE=1`. XWayland is the sharp path here, not Wayland: Omarchy's
`xwayland:force_zero_scaling` gives real device pixels, while GTK3 on Wayland gets
resampled by the 1.6 monitor scale (measured ~9x difference).

**Why:** depends on both the Omarchy Alt+Tab binding and `force_zero_scaling` staying as
they are — recheck after an upgrade. Details and the measurements in
[../remmina/README.md](../remmina/README.md).

---

## Tier 3 — small, easy to live without

- **`looknfeel.conf`**: `gaps_in = 1`, `gaps_out = 1` (stock is larger);
  `misc.focus_on_activate = false` — stops notifications and app activations from
  stealing focus mid-typing. The focus one is more valuable than the gaps.
- **`input.conf` pointer**: `accel_profile = flat`, `sensitivity = -0.3`,
  `repeat_delay = 600` (stock 250), touchpad `clickfinger_behavior` disabled,
  `scroll_factor = 0.4`. Mouse feel is exactly the kind of thing worth re-deriving on
  fresh defaults rather than restoring.
- **`uwsm/default`**: `EDITOR=zeditor` (stock `nvim`).
- **`envs.conf`** (user-created): `SDL_VIDEODRIVER=wayland`,
  `OMARCHY_SCREENSHOT_DIR=$HOME/Pictures/Screenshots`. Note v4 has a commented
  `OMARCHY_SCREENSHOT_DIR` in stock `uwsm/default` — use that slot instead.
- **`fcitx5` removed**: `environment.d/fcitx.conf` is deliberately absent. Recorded
  fact — stock fcitx5 broke Ctrl+C/Ctrl+V on the UA layout system-wide. **If v4
  reinstalls fcitx5, expect that regression to return.**
- **`foot/foot.ini`** absent — unused terminal, no action needed.
- **`pacman/makepkg.conf`** → `~/.config/pacman/makepkg.conf`: `MAKEFLAGS=-j$(nproc)`
  (stock builds single-threaded — icu76 took 4 min), `!debug` (no `-debug` packages
  that the orphan sweep deletes right after), `!check` (mdcat's tests recompile the
  whole crate tree a second time).

---

## Do not restore

Files that differ only because they are **stale copies of older Omarchy defaults**,
never deliberately customized. Take the v4 versions:

`git/config` · `tmux/tmux.conf` · `ghostty/config` (except font + F11) ·
`alacritty/alacritty.toml` (except font + F11) · `fastfetch/config.jsonc` ·
`hypr/hyprsunset.conf` · `hypr/xdph.conf` · `swayosd/config.toml` · `btop/btop.conf` ·
`opencode/opencode.json` · `chromium/Default/Preferences` ·
`systemd/user/omarchy-battery-monitor.service` · `Typora/themes/ia_typora_night.css`

`git/config` is worth calling out: the local copy is missing roughly ten upstream
settings — `push.autoSetupRemote`, `diff.algorithm = histogram`, `diff.colorMoved`,
`commit.verbose`, `branch.sort`, `rerere.enabled` and others — while keeping only
`pull.rebase`. The stock v4 file is strictly better.

Also stale and safe to drop: eleven `.bak` files across `~/.config/hypr` and
`~/.config/waybar`, and the `hyprctl reload` in `hypridle.conf` noted above.

---

## Known-unsolved, carried forward

- **NumLock desync after resume** (hyprlock #680). The numpad LED reads on but types
  nothing until NumLock is toggled twice. Matters because this keyboard's `. 0 - = /`
  keys are flaky, making the numpad the reliable way to type digits into the lock
  screen. Key injection cannot fix it; the compositor patch was built, tested, and
  **did not work** — it has been removed from this repo, do not retry that approach.
  Root-cause analysis is preserved in the project memory notes.

## Verification after upgrading

Re-run the survey that produced this file to see the new delta against v4 defaults:

```bash
cd ~/.local/share/omarchy && for f in $(git ls-tree -r --name-only HEAD -- config/ | sed 's|^config/||'); do u="$HOME/.config/$f"; [ ! -e "$u" ] && echo "MISSING   $f" || diff -q "config/$f" "$u" >/dev/null 2>&1 || echo "MODIFIED  $f"; done
```
