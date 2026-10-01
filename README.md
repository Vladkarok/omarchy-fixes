# Omarchy Fixes

Small fixes I keep around for an Omarchy setup.

This repo currently has six buckets:

- `waybar/`: custom Waybar widgets and config snippets
- `omarchy/`: power profile, brightness, and screenshot fixes for Omarchy
- `hypr/`: Hyprland config files with no upstream Omarchy equivalent
- `shell/`: zsh config and Powerlevel10k prompt
- `remmina/`: RDP client config — guest hotkeys and sharpness on a fractional-scale panel
- `docs/`: notes about this setup

See [docs/customizations.md](docs/customizations.md) for a full inventory of what is
customized against stock Omarchy and why — written to support wiping back to defaults
on the Omarchy 4.0 upgrade and re-adding tweaks deliberately.

## Waybar

Included files:

- `waybar/keyboard-layout.sh`: reliable keyboard layout indicator for Hyprland
- `waybar/calendar-toggle.py`: Waybar calendar icon with a small GTK popup
- `waybar/screen-keyboard.sh`: manual Waybar/Hyprland toggle for `wvkbd`
- `waybar/cpu-status.py`: CPU widget showing total usage % next to the icon, with per-core hover details and short load graphs
- `waybar/volume-status.py`: volume widget showing rough level glyphs with exact 0% and muted handling
- `waybar/brightness-status.py`: brightness widget status from the shared brightness curve helper
- `waybar/brightness-toggle.py`: toggles the custom brightness slider
- `waybar/brightness-slider.py`: GTK brightness slider backed by the shared brightness curve helper
- `waybar/examples/calendar-toggle.jsonc`: Waybar custom module for a popup calendar icon
- `waybar/examples/calendar-toggle.css`: matching calendar module spacing and active color
- `waybar/examples/screen-keyboard.jsonc`: Waybar custom module for manually toggling `wvkbd`
- `waybar/examples/screen-keyboard.css`: matching screen keyboard module spacing and active color
- `waybar/examples/memory-builtin.jsonc`: built-in Waybar memory widget example
- `waybar/examples/memory-builtin.css`: matching memory widget colors
- `waybar/examples/pulseaudio-volume-level.jsonc`: custom Waybar volume widget example showing rough volume level with compact glyphs
- `waybar/examples/pulseaudio-volume-level.css`: optional stable width for the volume widget
- `waybar/examples/backlight-linear.jsonc`: Waybar backlight module wired to the shared brightness curve helper

### Keyboard Layout Widget

This works around the known IPC parsing problems in Waybar's built-in `hyprland/language` module by treating the socket event as a trigger and reading the real layout state from `hyprctl devices -j`.

Dependencies:

- `hyprctl`
- `jq`
- `socat`

Install:

```bash
mkdir -p ~/.config/waybar/scripts
install -m755 waybar/keyboard-layout.sh ~/.config/waybar/scripts/keyboard-layout.sh
```

Find your keyboard device name:

```bash
hyprctl devices -j | jq -r '.keyboards[] | .name'
```

Waybar snippet:

```jsonc
"modules-right": [
  "custom/language"
],

"custom/language": {
  "exec": "~/.config/waybar/scripts/keyboard-layout.sh <YOUR_KEYBOARD_NAME>",
  "return-type": "json",
  "on-click": "hyprctl switchxkblayout all next"
}
```

Optional CSS:

```css
#custom-language.en {
  color: #89b4fa;
}

#custom-language.ua {
  color: #f9e2af;
}
```

### Calendar Toggle

This adds a Waybar calendar icon that opens a small GTK calendar popup. It is
self-contained and does not need `gsimplecal`, `yad`, or another external
calendar app.

Files:

- `waybar/calendar-toggle.py`
- `waybar/examples/calendar-toggle.jsonc`
- `waybar/examples/calendar-toggle.css`

Dependencies:

- `python3`
- `python-gobject`
- GTK 3
- `pgrep`
- `pkill`

Install:

```bash
mkdir -p ~/.config/waybar/scripts
install -m755 waybar/calendar-toggle.py ~/.config/waybar/scripts/calendar-toggle.py
```

Add `custom/calendar` to `modules-center`, for example next to the clock:

```jsonc
"modules-center": [
  "clock",
  "custom/calendar",
  "custom/weather"
]
```

Waybar snippet:

```jsonc
"custom/calendar": {
  "exec": "python3 ~/.config/waybar/scripts/calendar-toggle.py status",
  "return-type": "json",
  "format": "{}",
  "tooltip": true,
  "on-click": "python3 ~/.config/waybar/scripts/calendar-toggle.py toggle",
  "signal": 12,
  "interval": 60
}
```

Optional CSS:

```css
#custom-calendar {
  min-width: 12px;
  margin-left: 7.5px;
  margin-right: 7.5px;
}

#custom-calendar.active {
  color: #a55555;
}
```

### Screen Keyboard Toggle

This adds a manual Waybar icon for toggling `wvkbd`. The widget reports active
while the keyboard process is running, so it uses start/stop instead of
signal-based hide/show.

Files:

- `waybar/screen-keyboard.sh`
- `waybar/examples/screen-keyboard.jsonc`
- `waybar/examples/screen-keyboard.css`

Dependencies:

- `wvkbd`
- `pgrep`
- `pkill`

Install:

```bash
mkdir -p ~/.config/waybar/scripts
install -m755 waybar/screen-keyboard.sh ~/.config/waybar/scripts/screen-keyboard.sh
```

Add `custom/screen-keyboard` to `modules-right`, for example next to the
language indicator:

```jsonc
"modules-right": [
  "custom/language",
  "custom/screen-keyboard"
]
```

Waybar snippet:

```jsonc
"custom/screen-keyboard": {
  "exec": "~/.config/waybar/scripts/screen-keyboard.sh status",
  "return-type": "json",
  "format": "{}",
  "tooltip": true,
  "on-click": "~/.config/waybar/scripts/screen-keyboard.sh toggle",
  "signal": 11,
  "interval": 10
}
```

Optional CSS:

```css
#custom-screen-keyboard {
  min-width: 12px;
  margin-right: 12px;
}

#custom-screen-keyboard.active {
  color: #a55555;
}
```

Optional Hyprland binding:

```ini
bindd = SUPER ALT, K, Toggle screen keyboard, exec, ~/.config/waybar/scripts/screen-keyboard.sh toggle
```

### CPU Hover Widget

This replaces the stock `cpu` module with a custom widget that shows total CPU usage % to the left of the icon and exposes much more detail on hover.

Tooltip data:

- total CPU load
- per-core load
- per-core temperature when exposed by the kernel
- session peak temperature
- 10-sample CPU load sparklines for total and per-core history

Install:

```bash
mkdir -p ~/.config/waybar/scripts
install -m755 waybar/cpu-status.py ~/.config/waybar/scripts/cpu-status.py
```

Waybar snippet:

```jsonc
"modules-right": [
  "custom/cpu"
],

"custom/cpu": {
  "exec": "python3 ~/.config/waybar/scripts/cpu-status.py",
  "return-type": "json",
  "interval": 1,
  "tooltip": true
}
```

Optional CSS:

```css
#custom-cpu.warm {
  color: #d79921;
}

#custom-cpu.hot {
  color: #fe8019;
}

#custom-cpu.critical {
  color: #fb4934;
}
```

Notes:

- On many Intel CPUs, temperatures are exposed per physical core, not per logical thread.
- The `peak` value is tracked by the script for the current boot session.
- The sparkline is CPU load history, not temperature history.

### Built-in Memory Widget

If you do not need a custom RAM graph yet, the built-in `memory` module is enough — the example shows usage % next to the icon with a useful hover tooltip.

Files:

- `waybar/examples/memory-builtin.jsonc`
- `waybar/examples/memory-builtin.css`

Recommended behavior:

- show usage percentage to the left of the icon in the bar
- show percentage and used / total GiB on hover
- keep warning and critical colors through `states`

### Volume Level Indicator

Omarchy's stock `pulseaudio` module can show only one icon per output type and cannot distinguish exact `0%` from other values in the first icon bucket. The custom example keeps the widget icon-only but uses a tiny left-side level glyph for low / medium / high volume, with a distinct `×` marker for muted or exact `0%`.

Files:

- `waybar/examples/pulseaudio-volume-level.jsonc`
- `waybar/examples/pulseaudio-volume-level.css`
- `waybar/volume-status.py`

Recommended behavior:

- show rough low / medium / high output volume without another percentage
- show exact `0%` and muted as a distinct `×` state
- keep speaker, headphone, and headset states visually distinct

Dependencies:

- `pactl`
- `pamixer`

Install:

```bash
mkdir -p ~/.config/waybar/scripts
install -m755 waybar/volume-status.py ~/.config/waybar/scripts/volume-status.py
```

Replace `pulseaudio` with `custom/volume` in `modules-right`:

```jsonc
"modules-right": [
  "custom/volume"
]
```

Waybar snippet:

```jsonc
"custom/volume": {
  "exec": "python3 ~/.config/waybar/scripts/volume-status.py",
  "return-type": "json",
  "interval": 1,
  "on-click": "omarchy-launch-audio",
  "on-click-right": "pamixer -t",
  "on-scroll-up": "pamixer -i 5",
  "on-scroll-down": "pamixer -d 5",
  "tooltip": true
}
```

Optional CSS:

```css
#custom-volume {
  min-width: 28px;
}
```

Reload Waybar:

```bash
pkill -SIGUSR2 waybar
```

### Linear Brightness Controls

Omarchy's stock brightness controls operate directly on hardware backlight
percentages. On some panels, including `nvidia_wmi_ec_backlight`, that feels
non-linear: the top end changes slowly and the low end changes abruptly.

This repo keeps one shared gamma-corrected helper for display brightness:

- `omarchy/bin/omarchy-brightness-display`
- `waybar/brightness-status.py`
- `waybar/brightness-slider.py`
- `waybar/brightness-toggle.py`
- `waybar/examples/backlight-linear.jsonc`

The helper exposes adjusted user-facing percentages and maps them to raw
hardware backlight values with `OMARCHY_BRIGHTNESS_GAMMA` (default `2.2`). It
clamps normal brightness to `OMARCHY_BRIGHTNESS_MIN` (default `5`) as a real
hardware backlight floor, so normal brightness keys do not set the panel below
5%; display-off still uses the separate `off` action.

Install:

```bash
install -Dm755 omarchy/bin/omarchy-brightness-display ~/.local/bin/omarchy-brightness-display
install -Dm755 waybar/brightness-status.py ~/.config/waybar/scripts/brightness-status.py
install -Dm755 waybar/brightness-toggle.py ~/.config/waybar/scripts/brightness-toggle.py
install -Dm755 waybar/brightness-slider.py ~/.config/waybar/scripts/brightness-slider.py
```

Waybar snippet:

```jsonc
"custom/brightness": {
  "exec": "python3 ~/.config/waybar/scripts/brightness-status.py nvidia_wmi_ec_backlight",
  "return-type": "json",
  "on-click": "python3 ~/.config/waybar/scripts/brightness-toggle.py nvidia_wmi_ec_backlight",
  "on-scroll-up": "omarchy-brightness-display +5% nvidia_wmi_ec_backlight",
  "on-scroll-down": "omarchy-brightness-display 5%- nvidia_wmi_ec_backlight",
  "tooltip": true,
  "interval": 2
}
```

Fn brightness keys already call `omarchy-brightness-display` from Omarchy's
stock Hyprland media bindings. With `~/.local/bin` before Omarchy's bin
directory in `~/.config/uwsm/env`, this override applies to Fn keys, Waybar
scroll, and the slider. Change `OMARCHY_BRIGHTNESS_GAMMA` in one place to tune
the curve everywhere.

## Omarchy

Included files:

- `omarchy/bin/omarchy-powerprofiles-apply`
- `omarchy/bin/omarchy-powerprofiles-set`
- `omarchy/bin/omarchy-brightness-display`
- `omarchy/bin/omarchy-agent-usage-grok`: Grok collector for the `omarchy.agents` bar panel
- `omarchy/systemd/omarchy-agent-usage-grok.service`: writes the Grok usage record
- `omarchy/systemd/omarchy-agent-usage-grok.timer`: refreshes that record every 15 minutes
- `omarchy/bin/omarchy-claude-desktop-update`: installs Claude Desktop straight from Anthropic's apt index
- `omarchy/systemd/omarchy-claude-desktop-update.service` + `.timer`: checks for a new release every 15 minutes
- `omarchy/patches/omarchy-menu-power-profile.patch`
- `tensaku/config.toml`: closes the screenshot editor after copy/save/save-as

### Power Profile Fixes

These fix two separate issues in Omarchy's power profile flow:

1. `powerprofilesctl` can report a profile change while CPU governors remain stuck on `performance`, so the actual behavior does not change.
2. Walker can keep the visual focus on the first row, so the power menu can appear to highlight the wrong current profile.

### What The Fixes Do

- `omarchy-powerprofiles-apply` applies the requested profile and repairs the stuck-governor case before retrying.
- `omarchy-powerprofiles-set` routes AC and battery transitions through that helper.
- `omarchy-menu-power-profile.patch` makes the power menu put the current profile first and call the helper instead of raw `powerprofilesctl set`.

### Install

Copy the helper scripts into your Omarchy checkout:

```bash
install -Dm755 omarchy/bin/omarchy-powerprofiles-apply ~/.local/share/omarchy/bin/omarchy-powerprofiles-apply
install -Dm755 omarchy/bin/omarchy-powerprofiles-set ~/.local/share/omarchy/bin/omarchy-powerprofiles-set
```

Apply the menu patch from the Omarchy repo root:

```bash
cd ~/.local/share/omarchy
git apply /path/to/this/repo/omarchy/patches/omarchy-menu-power-profile.patch
```

Notes:

- The governor recovery path uses `sudo -n` when it is not already running as root.
- The helper only resets governors when a non-`performance` profile should be active and the kernel is still pinned to `performance`.

### Grok in the Agents Panel

The `omarchy.agents` bar widget ships collectors for Claude, Codex, and Fireworks
only. Grok has no collector upstream — seven PRs adding one were open against
`omacom/omarchy` as of 2026-08-31, none merged. `omarchy/bin/omarchy-agent-usage-grok`
is the collector from [PR 7393](https://github.com/omacom/omarchy/pull/7393),
which is the only one of the seven that touches no QML, so it drops in without
forking the plugin.

Token stats come from `turn_completed` events in
`~/.grok/sessions/*/*/updates.jsonl`. The plan label and the weekly pool come
from `cli-chat-proxy.grok.com`, the same endpoint Grok's own `/usage` command
uses, authenticated with the bearer token already in `~/.grok/auth.json`.

`omarchy-agent-usage-update` only globs `$OMARCHY_PATH/bin`, which the
`omarchy-dev` package owns, so the collector cannot register itself there. The
systemd user timer writes the record straight into the directory the panel
watches instead. The panel picks up any record that lands there regardless of
who wrote it, so nothing else needs changing.

#### Install

```bash
install -Dm755 omarchy/bin/omarchy-agent-usage-grok ~/.local/bin/omarchy-agent-usage-grok
install -Dm644 omarchy/systemd/omarchy-agent-usage-grok.service ~/.config/systemd/user/omarchy-agent-usage-grok.service
install -Dm644 omarchy/systemd/omarchy-agent-usage-grok.timer ~/.config/systemd/user/omarchy-agent-usage-grok.timer
systemctl --user daemon-reload && systemctl --user enable --now omarchy-agent-usage-grok.timer
```

Notes:

- The panel only re-lists the usage directory when its own update process exits,
  so a new record shows up at the next refresh. `omarchy-shell omarchy.agents refresh`
  forces it.
- The Grok mark needs `assets/grok.svg` inside the plugin directory, which lives
  under `/usr/share/omarchy`. Without cloning the plugin, Grok falls back to the
  generic bar glyph.
- Retire all of this once a Grok collector merges upstream: the packaged
  `omarchy-agent-usage-grok` will overwrite the same `grok.json`, so remove the
  timer and the `~/.local/bin` copy to avoid two writers.

### Claude Desktop Straight from Anthropic

Anthropic ships the Linux Claude Desktop (the app that hosts Claude Code)
only as a `.deb` in its apt repo, and the Linux build has no self-updater.
Omarchy repackages it into `[omarchy]` days later (2.7032.0: +2.5 days;
2.9939.4: still missing after 3), AUR `claude-desktop` follows within hours,
and yay never checks AUR for a package that also exists in a sync repo, so
even an AUR install stays frozen after the first `yay -Syu`.

`omarchy/bin/omarchy-claude-desktop-update` reads the apt `Packages` index,
and when it is ahead of the installed version, re-targets the AUR PKGBUILD
(the same `.deb` plus a Wayland launcher) at that version, builds it, installs
it with `pacman -U`, and sends a notification. The `[omarchy]` package never
wins back: pacman does not downgrade, and the repo is always behind.

```bash
install -Dm755 omarchy/bin/omarchy-claude-desktop-update ~/.local/bin/omarchy-claude-desktop-update
install -Dm644 omarchy/systemd/omarchy-claude-desktop-update.service ~/.config/systemd/user/omarchy-claude-desktop-update.service
install -Dm644 omarchy/systemd/omarchy-claude-desktop-update.timer ~/.config/systemd/user/omarchy-claude-desktop-update.timer
systemctl --user daemon-reload
systemctl --user enable --now omarchy-claude-desktop-update.timer
```

### Screenshot Annotation: Satty → Tensaku

**Nothing to install — Omarchy 4 replaced Satty entirely.**

Omarchy 4 drops Satty and ships [Tensaku](https://github.com/jondkinney/tensaku)
as the screenshot annotator (`tensaku` 0.28.0, GTK4 + libadwaita, MPL-2.0).
`omarchy-capture-screenshot` reads the editor from `$OMARCHY_SCREENSHOT_EDITOR`
and falls back to `tensaku-edit`, so it works with no configuration. The upgrade
uninstalls the `satty` package.

Tensaku is a Satty fork and keeps the same CLI surface — `--actions-on-enter`,
`--early-exit`, `--copy-command`, `--corner-roundness`,
`--annotation-size-factor`, `--default-hide-toolbars`. Its `--help` text still
carries Satty's own version notes verbatim ("0.20.1: This does not apply to save
as"), and the packaged wrapper `/usr/bin/tensaku-edit` says outright that it
matches "what Omarchy's built-in satty editor branch passes".

**The Save-As work survived the switch.** The filename prefill and remembered
directory from [gabm/satty#499](https://github.com/gabm/satty/pull/499) came
across with the fork: the wrapper passes `--output-filename`, which is all the
feature needs, and the remembered directory lands in
`~/.local/state/tensaku/save_as_last_dir`. No local patch, no config.

**Auto-close is back, and it is per action now.** The packaged wrapper passes
`--actions-on-enter save-to-clipboard --save-after-copy --copy-command wl-copy`
and does *not* pass `--early-exit`, so the auto-close that
`~/.config/satty/config.toml` used to provide has to be re-declared. Tensaku
reads `~/.config/tensaku/config.toml`:

```toml
[general]
close-on-copy = true
close-on-save = true
early-exit-save-as = true
```

Which key ends which action (`src/sketch_board.rs`):

| Action | Reached by | Closes on |
|---|---|---|
| `SaveToClipboard` | Enter, via the wrapper's `--actions-on-enter` | `close-on-copy` |
| `SaveToFile` | Ctrl+S | `close-on-save` |
| `SaveToFileAs` | Save As | `early-exit-save-as` |

Satty's old single `early-exit` still parses — it is a fallback that fills in
`close-on-copy` and `close-on-save` when neither is set explicitly — but it
never covered Save As, which is why the third key exists. Note that Enter runs
through *copy*, not save, even though `--save-after-copy` writes the file: with
only `close-on-save` set, the default Omarchy flow leaves the window open.

Config keys are validated on startup (`deny_unknown_fields`), so a typo is a
loud parse error rather than a silently ignored line. `tensaku --doctor` is
enough to check it.

Beyond Satty, Tensaku adds `--scroll-capture` (scrolling screenshots, with
auto-scroll over the xdg-desktop-portal RemoteDesktop/libei handshake),
`--resize smart`, `--fullscreen current|all`, and `--floating-hack`.

Migration cleanup, once Satty is gone:

```bash
rm -rf ~/.config/satty ~/.local/state/satty
```

Notes:

- Historical: a shell wrapper (`omarchy-cmd-screenshot`, `gsettings` filechooser
  hack) → a patched Satty build → upstream Satty 0.21.x → Omarchy 4 on Tensaku.
  Every local workaround on this path is now retired.
- Earlier stale PRs on this topic: #2421, #3226.
- Omarchy discussions #5438 (RESOLVED) and #5439 (OUTDATED) were closed against
  Satty and need no revisiting.

## Hyprland

Personal overrides that have **no upstream Omarchy equivalent**. Omarchy's
`omarchy refresh hyprland` can restore any of its own defaults, but it knows
nothing about these, so this is their only backup.

Omarchy 4 moved the whole config from `.conf` to Lua, and a `.lua` entry point
cannot `source` a `.conf` file, so the old files here were translated rather
than copied. `~/.config/hypr/hyprland.lua` loads Omarchy's defaults first and
the personal files after, which is what makes them win:

```lua
require("default.hypr.omarchy")
require("hypr.envs")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.windows")
```

### `hypr/windows.lua`

Per-app window rules, written with Omarchy's `o.window(match, rules)` helper.

Chat apps (Discord, Telegram, WhatsApp/Whatsie, Viber) land on workspace 1 as a
single tabbed group. `group = "set"` opens each as a group and Hyprland's
`group.auto_group` merges the next one in, so the rules deliberately do *not*
use `silent` — auto-group only merges into the **focused** group, and
`autostart.lua` staggers the launches so they map in order.

Two rules are load-bearing in a way that is easy to undo by accident:

- `float = false` on chat apps and on Last War. These map transient splash or
  login windows under the same class; one floating member drags the entire
  group floating.
- `group = "override barred"` on Telegram's media viewer and Discord's updater.
  Both share the class of their main window, so without it they join the group
  and hijack it — fullscreen a picture, close it, and the survivor stays stuck
  fullscreen.

The opacity line restates Omarchy's own `default-opacity` tag rule (`"1 0.96"`)
so the focused window is fully opaque; Omarchy applies opacity through that tag,
not through `decoration:active_opacity`, so overriding it requires restating the
tag rule after the defaults load.

App classes were found by trial and error and are not guessable — Whatsie
reports `com.ktechpit.whatsie`, Last War runs as `steam_proton` and is separated
from its launcher only by window title.

### `hypr/looknfeel.lua`

Zero gaps, `misc:focus_on_activate = false` (an activation request from another
workspace should not yank the view over — this was in the old `looknfeel.conf`
and the Lua migration dropped it), and a tightened groupbar: no indicator gap,
3px between tabs, and opaque tab chips so the wallpaper shows only in the seams
and the tab borders stay readable.

### `hypr/bindings.lua`

Personal rebinds only, each through a local `rebind()` that unbinds first so a
future Omarchy update cannot claim the key back: Last War, ChatGPT and Claude
desktop apps over Omarchy's web-app bindings, `emote` as the emoji picker, a
lid-close handler that turns the panel off without locking, a passthrough submap
for RDP/VM guests, and `SUPER + CTRL + SHIFT + arrows` to reorder tabs inside a
group (Omarchy binds only focus movement, `SUPER + CTRL + arrows`).

### `hypr/envs.lua`

`SDL_VIDEODRIVER=wayland`, a custom `OMARCHY_SCREENSHOT_DIR`, and
`LIBVA_DRIVER_NAME=iHD` — on this hybrid-GPU laptop Omarchy's `nvidia.lua`
forces the `nvidia` VA-API driver, which breaks video decode in every
Chromium-based app.

### Install

```bash
cp hypr/*.lua ~/.config/hypr/
hyprctl reload && hyprctl configerrors
```

`hyprland.lua` is included, so this also restores the `require` order above.
See [docs/customizations.md](docs/customizations.md) for the full inventory
(still written against the pre-Omarchy-4 `.conf` layout).

## Shell

Zsh setup with a Powerlevel10k prompt. Stored without the leading dot so the
files stay visible; the mapping is:

| repo | installed as |
| --- | --- |
| `shell/zshrc` | `~/.zshrc` |
| `shell/zsh_aliases` | `~/.zsh_aliases` |
| `shell/p10k.zsh` | `~/.p10k.zsh` |

### Prompt

Powerlevel10k in Pure style (`p10k-pure.zsh`, snazzy colors, 2-line, transient
prompt, instant prompt). `.zshrc` keeps three ordering rules that matter:

- the instant-prompt block must stay at the **top** of the file
- `zsh-syntax-highlighting` must be sourced **last** among plugins
- the prompt theme is sourced **last** overall, and keybindings come after the
  plugins so they are not overridden

### Not self-contained

These files only configure things — they do not install them. A fresh machine
needs the plugins and theme checked out under `~/.oh-my-zsh/custom/` first:

- `plugins/zsh-autosuggestions`
- `plugins/zsh-syntax-highlighting`
- `themes/powerlevel10k`

`.zshrc` also assumes these are on PATH and will error noisily without them:
`zoxide`, `fzf`, `fnm`, plus `eza`, `bat`, `broot`, `nvim` for the aliases.
Some blocks are installer-managed (grok, agterm agent-status, the Oracle CLI
completion, and the `~/.local/bin/env` line from the uv installer) and will be
rewritten by those tools rather than by hand.

### Install

```bash
cp shell/zshrc ~/.zshrc
cp shell/zsh_aliases ~/.zsh_aliases
cp shell/p10k.zsh ~/.p10k.zsh
exec zsh
```

Run `p10k configure` to regenerate the prompt from scratch instead.

Note: `~/.config/starship.toml` also exists on this system but nothing sources
it — a leftover from before the switch to Powerlevel10k. It is not tracked here.

## Tested On

- Omarchy 3.5.1
- Hyprland 0.54.1
- Waybar 0.15.0
- Arch Linux

## License

MIT
