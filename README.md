# Omarchy Fixes

Fixes and personal overrides for one Omarchy 4.x laptop (Arch, package-managed
`omarchy-dev`, hybrid Intel/NVIDIA, 2560x1600 panel at scale 2, US + UA
keyboard layouts). Each directory below says what it fixes, where its files go,
and how to install them. The restore checklist at the end puts them in order
for a fresh machine.

Commands assume you are in the repo root.

## Directories

### `pacman/local-patched-repo/`

An unsigned `file://` pacman repository, `[local-patched]`, served from
`/var/lib/local-patched-repo` and listed before `[omarchy]`. pacman takes a
package from the first repository that lists it, so the patched `hyprland`,
`hyprpm` and `remmina` builds survive `omarchy update` and channel switches.

| File | Goes to |
| --- | --- |
| `custom-repos.conf` | `/etc/pacman.d/custom-repos.conf` (included from `/etc/pacman.conf`) |
| `10-local-patched-repo` | `~/.config/omarchy/hooks/pre-refresh-pacman.d/` (re-adds the Include after Omarchy rewrites `pacman.conf`) |
| `20-warn-shadowed-local-pkgs` | `~/.config/omarchy/hooks/post-update.d/` (warns when Arch or Omarchy has a newer build than the published one) |
| `publish-local-pkg.sh` | run from the repo; copies packages into the repo and runs `repo-add` |
| `install.sh` | run from the repo; one-time setup |

Build the packages first (see `hyprland/` and `remmina/`), then run from a
normal terminal (not one with no-new-privileges, such as Claude Desktop's):

```bash
pacman/local-patched-repo/install.sh          # newest packages in hyprland/ and remmina/
pacman/local-patched-repo/install.sh DIR|PKG  # or packages from elsewhere
omarchy update
```

`install.sh` stops if it cannot find a `hyprland`, `hyprpm` or `remmina`
package. To publish a later build: `pacman/local-patched-repo/publish-local-pkg.sh <pkg>...`,
then `omarchy update`.

### `hyprland/`

Omarchy's hyprland 0.57.1-2 recipe rebuilt as `0.57.1-2.1` with two local patches:

- `0001-hyprland-seat-keyboard-v8-core.patch`: keeps the keyboard layout and
  modifiers consistent across keyboards on the seat.
- `0002-hyprland-resume-schedule-frame.patch`: repaints outputs after resume.

The other three patches (`nvidia-egl-teardown`, `wl-output-global-grace`,
`monitor-rule-vrr`) are Omarchy's own. Neither local patch is in upstream
v0.57.2, so when Omarchy moves to a new version, rebase the PKGBUILD on its
recipe and keep both patches.

```bash
cd hyprland && makepkg -s
```

Build output is gitignored. Publish `hyprland-*.pkg.tar.zst` and
`hyprpm-*.pkg.tar.zst` together.

### `remmina/`

Remmina on native Wayland with a HiDPI dynamic-resolution patch, a desktop
override, the tray-icon fix and example config. Details in
[remmina/README.md](remmina/README.md).

- `PKGBUILD`, `remmina-hidpi-dynres.patch`: build with `cd remmina && makepkg -df`.
- `org.remmina.Remmina.desktop` → `~/.local/share/applications/`
  (`GDK_BACKEND=wayland`, `GTK_THEME=Adwaita-dark`).
- `remmina.pref.example` → `~/.config/remmina/remmina.pref`, and
  `rdp-profile.example.remmina` → `~/.local/share/remmina/`. Secrets, hosts and
  domains are blanked; fill them in with Remmina closed.
- Tray icon: `ln -sfn /usr/share/icons/Yaru-dark ~/.local/share/icons/Yaru-gray`.

**Rebuild needed.** The published build is `1:1.4.43-4.1`, and `extra` now
ships `1:1.4.43-5`, which `[local-patched]` hides. Rebase the PKGBUILD on
extra's `-5`, set `pkgrel=5.1`, rebuild, and publish it.

### `hypr/`

Personal Hyprland overrides with no Omarchy equivalent. Copy them to
`~/.config/hypr/`. `hyprland.lua` loads Omarchy's defaults first and these files
after, so they win.

- `hyprland.lua`: the `require` order. It also loads `hypr.monitors` and
  `hypr.input`, which are not in this repo (see "Not captured yet").
- `envs.lua`: `LIBVA_DRIVER_NAME=iHD` (Omarchy's `nvidia.lua` forces `nvidia`,
  which breaks video decode in Chromium apps on this hybrid laptop),
  `SDL_VIDEODRIVER=wayland`, `OMASNAP_NOTIFY=0`, the screenshot directory.
- `bindings.lua`: rebinds through a local `rebind()` that unbinds first, so an
  Omarchy update cannot take a key back. Desktop apps over web-app binds, emote,
  lid close, a `SUPER + F12` passthrough submap for RDP and VM guests, tab
  reordering, keycode-based clipboard binds for the UA layout, `SUPER + SHIFT + Z`
  for ZCode, Discord push-to-talk on the backtick keycode, and the old dictation
  keys.
- `windows.lua`: chat apps as one tabbed group on workspace 1, Last War and its
  launcher on workspace 5 (with `no_max_size`, needed since Hyprland 0.57),
  `render_unfocused` so Proton games keep loading while their workspace is
  hidden, and Telegram's media viewer and Discord's updater kept out of the
  group.
- `looknfeel.lua`: no gaps, no border, rounding 4, `focus_on_activate = false`,
  a tighter groupbar, pointer kept visible after key presses.
- `autostart.lua`: launches the chat apps (Telegram, ZapZap, Viber, ...) one
  after another so they land in the same group.

```bash
cp hypr/*.lua ~/.config/hypr/
hyprctl reload && hyprctl configerrors
```

### Terminals: `alacritty/`, `foot/`, `ghostty/`, `kitty/`

Make Ctrl+C and Ctrl+V work in the UA layout by sending them as C0 bytes and
matching copy and paste by physical key. kitty also sets the font to
CaskaydiaMono 12.

| File | Goes to |
| --- | --- |
| `alacritty/alacritty.toml` | `~/.config/alacritty/alacritty.toml` |
| `foot/foot.ini` | `~/.config/foot/foot.ini` |
| `ghostty/config` | `~/.config/ghostty/config` |
| `kitty/kitty.conf` | `~/.config/kitty/kitty.conf` |

### `environment.d/electron-wayland.conf`

`ELECTRON_OZONE_PLATFORM_HINT=wayland` for every Electron app and launch path.
Copy to `~/.config/environment.d/` and log out and back in. Discord is the
exception: its desktop override passes `--ozone-platform=x11`, because its
push-to-talk recorder only sees X11 key events.

### `claude/com.anthropic.Claude.desktop`

Claude Desktop entry with `--password-store=gnome-libsecret`, so its login
survives restarts under Hyprland. Copy to `~/.local/share/applications/`.

### `chatgpt/codex-flags.conf`

Wayland Ozone flags for the `openai-codex-desktop` app. Omarchy's
`/usr/bin/chatgpt` launcher reads `~/.config/codex-flags.conf`; the env hint
alone loses to the launcher's own `--ozone-platform=x11`. Copy to
`~/.config/codex-flags.conf`.

### `viber/viber.desktop`

Starts Viber with `CUDA_VISIBLE_DEVICES=-1` so the NVIDIA GPU can
runtime-suspend. Copy to `~/.local/share/applications/`.

### `agterm/`

Install notes and a desktop entry for the agterm-linux tarball, which has no
package. See [agterm/README.md](agterm/README.md); the desktop entry goes to
`~/.local/share/applications/`. The notes were written for `linux-v0.19.0`;
check them against the version you install.

### `anydesk/`

An Omarchy post-update hook that pins AnyDesk to 100% scaling and a dark GTK
theme. Install AnyDesk first, then:

```bash
install -Dm755 anydesk/anydesk-100scale-post-update ~/.config/omarchy/hooks/post-update.d/anydesk-100scale
~/.config/omarchy/hooks/post-update.d/anydesk-100scale
```

Details in [anydesk/README.md](anydesk/README.md).

### `pacman/makepkg.conf`

Parallel builds (`-j$(nproc)`), no debug packages, no `check()`. Copy to
`~/.config/pacman/makepkg.conf`.

### `mise/global-config.toml`

Copy to `~/.config/mise/config.toml` (the repo name keeps mise from reading it
as a project config). It disables the baked aqua registry and installs herdr
from mise instead of the `[omarchy]` package, which lags releases. Remove the
pacman `herdr` package so the mise shim is the only one on PATH;
`omarchy update` keeps it current through `omarchy-update-mise`.

### `shell/`

zsh with oh-my-zsh plugins and a Powerlevel10k prompt.

| File | Goes to |
| --- | --- |
| `shell/zshrc` | `~/.zshrc` |
| `shell/zsh_aliases` | `~/.zsh_aliases` |
| `shell/p10k.zsh` | `~/.p10k.zsh` |

The files configure but do not install. Check out
`zsh-autosuggestions`, `fast-syntax-highlighting` (plugins) and `powerlevel10k`
(theme) under `~/.oh-my-zsh/custom/` first, and install `zoxide`, `fzf`, `fnm`,
`eza`, `bat`, `broot` and `nvim`. Aliases are skipped when `CLAUDECODE` is set.
The grok, agterm, LM Studio, Oracle CLI and uv blocks are written by those
installers and point at paths that exist only once they have run.

### `snapper/`

Hourly snapper snapshots of `/home`. Omarchy only snapshots root, and its
`install/config/snapper.sh` resets `/etc/conf.d/snapper` to root and disables
`snapper-timeline.timer`, so `/home` gets its own timer that does not depend on
that file.

```bash
sudo snapper -c home create-config /home
sudo snapper -c home set-config TIMELINE_CREATE=no TIMELINE_LIMIT_HOURLY=12 TIMELINE_LIMIT_DAILY=7 TIMELINE_LIMIT_WEEKLY=2 TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 TIMELINE_MIN_AGE=1800 NUMBER_LIMIT=5 ALLOW_USERS="$USER" SYNC_ACL=yes
sudo install -Dm644 snapper/snapper-home.service /etc/systemd/system/snapper-home.service
sudo install -Dm644 snapper/snapper-home.timer /etc/systemd/system/snapper-home.timer
sudo systemctl daemon-reload && sudo systemctl enable --now snapper-home.timer
```

Restore a file by copying it from `/home/.snapshots/<n>/snapshot/...`, or with
`snapper -c home undochange <n>..0 <path>`. Make VM images, `~/.cache` and other
churning directories nested subvolumes so they stay out of the snapshots:

```bash
btrfs subvolume create DIR.new && cp -a --reflink=always DIR/. DIR.new/ && mv DIR DIR.old && mv DIR.new DIR
```

Check the listing, then delete `DIR.old`.

### `omarchy/`

Local additions to Omarchy's shell. All are optional, and some overlap with
collectors Omarchy now ships.

- `bin/omarchy-agent-usage-grok` with `systemd/omarchy-agent-usage-grok.{service,timer}`:
  Grok usage for the agents panel, written every 15 minutes, refreshing an
  expired token with the refresh token in `~/.grok/auth.json`.
- `bin/omarchy-agent-usage-zai` with `systemd/omarchy-agent-usage-zai.{service,timer}`:
  Z.ai GLM Coding Plan usage. The key comes from
  `~/.config/omarchy/agents/zai.json`, `ZAI_API_KEY`, or ZCode's
  `~/.zcode/v2/config.json`; it is never stored in this repo.
- `bin/omarchy-zai-account`: manages more than one Z.ai account. `add <label>`
  stores a console key in `zai.json`; `attach <label>` writes it into ZCode's
  `builtin:zai` provider and generates an `omarchy-agent-usage-zai-<label>`
  service and timer. Also `list`, `label`, `status`, `detach`, `sync`, `remove`.
- `bin/omarchy-brightness-display`: brightness with a gamma 2.2 curve and a 5%
  floor for `nvidia_wmi_ec_backlight`. It shadows Omarchy's command because
  `~/.local/bin` comes first in Hyprland's PATH.
- `patches/notification-toast-layer-crash.patch`: fixes omarchy-shell aborting
  when an image notification is shown during a scale change
  ([omacom/omarchy#16937](https://github.com/omacom/omarchy/issues/16937)).
  Apply with `sudo patch -d /usr/share/omarchy -p1 < omarchy/patches/notification-toast-layer-crash.patch`;
  every `omarchy-dev` update reverts it.

```bash
for f in omarchy/bin/*; do install -Dm755 "$f" ~/.local/bin/"${f##*/}"; done
install -Dm644 -t ~/.config/systemd/user omarchy/systemd/*
systemctl --user daemon-reload
systemctl --user enable --now omarchy-agent-usage-grok.timer omarchy-agent-usage-zai.timer
```

Omarchy's own `omarchy-agent-usage-update` now writes `grok.json` and
`zai.json` too, so with these timers enabled two writers update the same
records. Disable a local timer once the packaged collector covers what you
need.

## Restore checklist for a fresh Omarchy 4.x machine

1. Install Omarchy 4.x and finish its first-run setup. Clone this repo.
2. Keyboard and display, by hand until they are captured here: in
   `~/.config/hypr/input.lua` set `kb_layout = "us,ua"` and
   `kb_options = "shift:both_capslock_cancel,grp:caps_toggle"` (Caps Lock
   switches layout); in `~/.config/hypr/monitors.lua` set `GDK_SCALE = 2` and
   monitor `scale = 2`. Add the `$LAYOUT[EN,UA]` label to `hyprlock.conf` so the
   lock screen shows the active layout.
3. Copy `hypr/*.lua` to `~/.config/hypr/` and run `hyprctl reload`.
4. Copy the terminal configs, `environment.d/electron-wayland.conf`,
   `pacman/makepkg.conf` and the shell files. Install the zsh plugins and theme.
5. Build `hyprland/` and `remmina/` with makepkg, run
   `pacman/local-patched-repo/install.sh`, then `omarchy update`. Log out and
   back in.
6. Install the desktop overrides (`claude/`, `viber/`, `remmina/`, `agterm/`)
   and `chatgpt/codex-flags.conf`, after the apps themselves. Install the
   AnyDesk hook after AnyDesk.
7. Copy `mise/global-config.toml` to `~/.config/mise/config.toml`, remove the
   pacman `herdr`, and run `mise install`.
8. Set up snapper for `/home` (`snapper/`).
9. Optional: the `omarchy/` collectors and brightness fork. Put the Z.ai key in
   `~/.config/omarchy/agents/zai.json` (mode 0600) and log in to Grok and ZCode
   before enabling the timers.
10. Things to check rather than copy:
    - Idle and lock timings live in `~/.config/omarchy/shell.json`
      (`idle.lock`, `idle.screensaver`); `hypridle` is not running, so
      `hypridle.conf` has no effect.
    - fcitx5 broke Ctrl+C and Ctrl+V in the UA layout system-wide. If Omarchy
      installs it again, expect that back.
    - `omarchy-refresh-limine` replaces `/boot/limine.conf`. Re-add
      `remember_last_entry: yes` afterwards.
    - Do not put multi-line secrets in the empty-password GNOME keyring. It
      stores them unescaped and the next daemon start fails to load the
      keyring; store them base64-encoded on one line. If the keyring is ever
      broken, fix it before opening a Chromium browser, which deletes cookies it
      cannot decrypt.
    - Take Omarchy's versions of git, tmux, fastfetch, btop, swayosd and
      hyprsunset config; the old copies were only stale defaults.
    - Known unsolved: after resume the NumLock LED reads on but the numpad types
      nothing until NumLock is toggled twice (hyprlock #680).

## Not captured yet

These are live on the machine but have no copy here:

- `~/.config/hypr/input.lua`, `monitors.lua`, `hypridle.conf`, `hyprlock.conf`,
  `hyprsunset.conf`
- `omarchy-agent-usage-zai-second.{service,timer}` (generated by
  `omarchy-zai-account attach second`)
- `/etc/sysctl.d/40-disable-ipv6.conf`, `/etc/sysctl.d/99-sysctl.conf`,
  `/etc/udev/rules.d/70-wifi-powersave-off.rules`,
  `/etc/systemd/system/user@.service.d/faster-shutdown.conf`
- Looking Glass and VFIO setup (kvmfr modprobe and udev rules, launcher scripts)
- `/etc/modprobe.d/disable-usb-autosuspend.conf`, `nvidia.conf`,
  `hid_apple.conf` (check whether Omarchy writes them)
- `~/.config/systemd/user/voxtype.service.d/gpu.conf`
- OSKar user units (`oskar.service`, `oskar-seat-watch.service`)
- The local `~/.local/bin/omasnap` build
- Desktop overrides: `discord.desktop`, `LastWar.desktop`,
  `ChatGPT-Second.desktop`, `anydesk.desktop`
- Personal scripts in `~/.local/bin` (Last War launcher and installer, RDP and
  recording helpers)
- Omarchy shell state: `shell.json`, `shell.toml`, the `neutral-dark` theme,
  `hooks/theme-set.d/10-owe-sync`, and the list of installed shell plugins
- A package list (repo and AUR packages)
- `~/.config/environment.d/omarchy-firefox-wayland.conf` (may come from Omarchy)

## License

MIT
