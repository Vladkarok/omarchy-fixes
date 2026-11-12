# Omarchy Fixes

Fixes and personal overrides for one Omarchy 4.x laptop (Arch, package-managed
`omarchy-dev`, hybrid Intel/NVIDIA, 2560x1600 panel at scale 2, US + UA
keyboard layouts). Each directory below says what it fixes, where its files go,
and how to install them. `bootstrap.sh` (see "Bootstrap" near the end) runs them
in order on a fresh machine.

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

Omarchy's hyprland 0.57.2-2 recipe rebuilt as `0.57.2-2.1` with two local patches:

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

The published build is `1:1.4.43-5.1`, on top of `extra`'s `1:1.4.43-5`. The
`20-warn-shadowed-local-pkgs` hook warns when `extra` moves ahead of it.

### `hypr/`

Personal Hyprland overrides with no Omarchy equivalent. Copy them to
`~/.config/hypr/`. `hyprland.lua` loads Omarchy's defaults first and these files
after, so they win.

- `hyprland.lua`: the `require` order. It also loads `hypr.input` (below) and
  `hypr.monitors` (in `hardware/hypr/`, because it is specific to this panel).
- `input.lua`: `us,ua` layouts toggled with Alt+Shift, Compose on Caps Lock,
  flat mouse acceleration at sensitivity -0.3. The comments explain why the
  toggle must not move to Caps Lock (it broke switching in fcitx5 apps).
- `hyprsunset.conf`: Omarchy's identity profile with `time = 40:00` instead of
  `07:00`. No clock reaches 40:00, so the profile never fires on its own and
  the night light stays as the panel left it.
- `envs.lua`: `LIBVA_DRIVER_NAME=iHD` (Omarchy's `nvidia.lua` forces `nvidia`,
  which breaks video decode in Chromium apps on this hybrid laptop),
  `SDL_VIDEODRIVER=wayland`, `OMASNAP_NOTIFY=0`.
- `bindings.lua`: rebinds through Omarchy's `o.rebind`, which unbinds first, so
  an Omarchy update cannot take a key back. Write the modifiers in the order
  Omarchy's own bind uses, or the unbind misses it and both binds fire. Desktop apps over web-app binds, emote,
  lid close, a `SUPER + F12` passthrough submap for RDP and VM guests, tab
  reordering, keycode-based clipboard binds for the UA layout, `SUPER + SHIFT + Z`
  for ZCode, Discord push-to-talk on the backtick keycode, and the old F9 dictation
  push-to-talk key.
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
cp hypr/*.lua hypr/hyprsunset.conf ~/.config/hypr/
hyprctl reload && hyprctl configerrors
```

### Terminals: `alacritty/`, `foot/`, `ghostty/`, `kitty/`

Make Ctrl+C and Ctrl+V work in the UA layout by sending them as C0 bytes and
matching copy and paste by physical key. They also set the font:
CaskaydiaMono 8 in alacritty and ghostty, CaskaydiaMono 12 in kitty and
JetBrainsMono 8 in foot (Omarchy's own configs use JetBrainsMono 9).

| File | Goes to |
| --- | --- |
| `alacritty/alacritty.toml` | `~/.config/alacritty/alacritty.toml` |
| `foot/foot.ini` | `~/.config/foot/foot.ini` |
| `ghostty/config` | `~/.config/ghostty/config` |
| `kitty/kitty.conf` | `~/.config/kitty/kitty.conf` |

### `claude/claude-desktop-flags.conf`

Adds `--password-store=gnome-libsecret` to Claude Desktop, so its login survives restarts under Hyprland. Omarchy's `/usr/bin/claude-desktop` launcher reads `~/.config/claude-desktop-flags.conf` on every launch (menu entry, `claude://` links, keybinding, bare command) and adds `--ozone-platform=wayland` itself. Copy to `~/.config/claude-desktop-flags.conf`.

### `chatgpt/codex-flags.conf`

Wayland Ozone flags for the `openai-codex-desktop` app. Omarchy's `/usr/bin/chatgpt` launcher reads `~/.config/codex-flags.conf` and already requests Wayland on its own; the file keeps Wayland explicit and adds `WaylandWindowDecorations`. Copy to `~/.config/codex-flags.conf`.

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
`eza`, `bat` and `nvim`. Aliases are skipped when `CLAUDECODE` is set.
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

Local additions to Omarchy's shell. All are optional.

The agents panel's `grok.json` and `zai.json` records come from Omarchy's own
`omarchy-agent-usage-update`. This repo used to ship its own Grok and Z.ai
collectors with timers, written before Omarchy had any; they raced the
packaged ones for the same files and were removed. The stock Z.ai collector
does not read ZCode's login, so the primary account needs its key as
`apiKey` in `~/.config/omarchy/agents/zai.json` or as `ZAI_API_KEY`.
On this machine it is a copy of ZCode's `builtin:zai-coding-plan` key from
`~/.zcode/v2/config.json`; copy it again if the panel reports a rejected key
after a new ZCode login.

- `bin/omarchy-agent-usage-zai` with
  `systemd/omarchy-agent-usage-zai-second.{service,timer}`: usage for a second
  Z.ai GLM Coding Plan account, written to `zai-second.json` every 15
  minutes. Omarchy has no equivalent. The timer runs the collector with
  `--account second`, which reads that account's key from
  `~/.config/omarchy/agents/zai.json`; the key is never stored in this repo.
- `bin/omarchy-zai-account`: manages more than one Z.ai account. `add <label>`
  stores a console key in `zai.json`; `attach <label>` writes it into ZCode's
  `builtin:zai` provider and generates an `omarchy-agent-usage-zai-<label>`
  service and timer (the `second` pair is the one tracked here). Also `list`,
  `label`, `status`, `detach`, `sync`, `remove`.

```bash
for f in omarchy/bin/*; do install -Dm755 "$f" ~/.local/bin/"${f##*/}"; done
install -Dm644 -t ~/.config/systemd/user omarchy/systemd/*
systemctl --user daemon-reload
omarchy-zai-account add second   # asks for the second account's console key
systemctl --user enable --now omarchy-agent-usage-zai-second.timer
```

`omarchy-zai-account attach second` also puts that key into ZCode and
rewrites the same two units.

### `omarchy/shell/` and `omarchy/themes/neutral-dark/`

The Omarchy shell's own settings and a custom theme.

| File | Goes to |
| --- | --- |
| `omarchy/shell/shell.json` | `~/.config/omarchy/shell.json` (mode 0600, as the shell writes it) |
| `omarchy/shell/shell.toml` | `~/.config/omarchy/shell.toml` |
| `omarchy/themes/neutral-dark/*` | `~/.config/omarchy/themes/neutral-dark/` |

- `shell.json`: the bar layout (world clocks, keyboard layout, weather,
  WireGuard, radio, omabump, OSKar, agents, activity monitor), the built-in lock
  screen disabled in favour of Lock Explorer, and idle timings (`idle.lock`
  300 s, `idle.screensaver` 150 s). The clock's `birthYear` is removed from
  this copy; set it again if you want the life-progress view. The plugin
  entries only work once the plugins are installed (below).
- `shell.toml`: shell font base size 11.
- `neutral-dark`: grey surfaces with equal RGB channels, hue-correct ANSI
  colours, `Yaru-dark` icons (part of the Remmina tray fix) and the GitHub Dark
  VS Code theme. The three wallpapers in its `backgrounds/` are not in the repo;
  add your own images there.

Install the third-party plugins before restoring `shell.json`:

```bash
omarchy plugin add https://github.com/AksharP5/omarchy-radio-atlas.git --yes
omarchy plugin add https://github.com/glafeara/omarchy-wireguard.git --yes
omarchy plugin add https://github.com/SirJul1337/omarchy-lock-explorer.git --yes
omarchy plugin add https://github.com/stappmus/omarchy-activity-monitor.git --yes
```

The owner's own plugins are linked from clones rather than installed:
`~/.config/omarchy/plugins/io.github.vladkarok.omabump` →
[Vladkarok/omabump](https://github.com/Vladkarok/omabump) and
`io.github.vladkarok.oskar` → [Vladkarok/oskar](https://github.com/Vladkarok/oskar)
(see "Other repositories").

Then restore the files and pick the theme:

```bash
install -Dm600 omarchy/shell/shell.json ~/.config/omarchy/shell.json
install -Dm644 omarchy/shell/shell.toml ~/.config/omarchy/shell.toml
mkdir -p ~/.config/omarchy/themes/neutral-dark/backgrounds
cp omarchy/themes/neutral-dark/* ~/.config/omarchy/themes/neutral-dark/
```

The other hooks under `~/.config/omarchy/hooks` come from packages and need no
copy: `theme-set` is written by `omazed`, `theme-set.d/10-owe-sync` is
`/usr/share/owe/10-owe-sync` from `owe`, and `post-update.d/setup-agent.hook`
is Omarchy's. The `pacman/` and `anydesk/` hooks are covered above.

### `local-bin/`

Small scripts for `~/.local/bin` that are not tied to Omarchy or to this
laptop's hardware.

| File | What it does |
| --- | --- |
| `rdp-connect` | `xfreerdp3` to one Windows machine with the client flags that work here: `+dynamic-resolution /scale:140 /gfx:AVC444 /bpp:32 /cert:tofu +auto-reconnect +floatbar`. Extra arguments are passed through (`rdp-connect /f`). |
| `rdp-connect.env.example` | template for `~/.config/rdp-connect.env`: `RDP_HOST`, `RDP_USER`, optional `RDP_DOMAIN` and `RDP_SCALE`. No password; xfreerdp3 asks for it. |
| `opencode-npx` | runs the newest `opencode-ai` from npm through `mise exec node@latest -- npx`, next to the mise-managed `opencode`, for trying a release before mise has it. |
| `xclicker-wrapper` | starts xclicker from a login shell so it gets the full login environment. The package's desktop entry runs `xclicker` directly and works too, so this is optional. |

```bash
for f in rdp-connect opencode-npx xclicker-wrapper; do install -Dm755 local-bin/$f ~/.local/bin/$f; done
install -Dm600 local-bin/rdp-connect.env.example ~/.config/rdp-connect.env   # then fill it in
```

Variables already in the environment win over the file, and
`RDP_CONNECT_ENV=/path/to/other.env rdp-connect` picks another machine. The
owner's own copy of the script, with the real host and user written in, stays
out of the repo.

### `applications/`

Desktop entry overrides and small launchers for `~/.local/share/applications/`.
Install the app first; an override for an app that is not installed is just a
broken menu entry.

Stock Omarchy's `hypr/envs.lua` exports `ELECTRON_OZONE_PLATFORM_HINT=wayland`, so Electron apps run on native Wayland. That matters for the on-screen keyboard: it types with `wtype` (the Wayland virtual-keyboard protocol), and an XWayland window drops those keys. Discord stays on XWayland with `--ozone-platform=x11`, because its push-to-talk keybind recorder only sees X11 key events; the on-screen keyboard cannot type into Discord as a result.

| File | What it changes |
| --- | --- |
| `discord.desktop` | `--ozone-platform=x11`, so Discord's push-to-talk recorder sees keys; keeps the package's `discord://` URL handling |
| `ChatGPT-Second.desktop` | a second ChatGPT/Codex instance with its own `CODEX_HOME` (`~/.codex-second`) and user data dir (`~/.config/Codex-second`) |
| `com.teamviewer.TeamViewer.desktop` | unsets `__GLX_VENDOR_LIBRARY_NAME`, so TeamViewer does not start on the NVIDIA GLX vendor |
| `com.uploadedlobster.peek.desktop` | Peek on X11 (`GDK_BACKEND=x11`), with D-Bus activation off so the override is used |
| `webcam-preview.desktop` | "Webcam" entry: an mpv preview of `/dev/video0` before a call |
| `LastWar.desktop` | starts Last War through `~/Work/lwupdate/lastwar-launch-auto.sh` from the private [Vladkarok/lwupdate](https://github.com/Vladkarok/lwupdate) repo; the icon comes from the game's Proton prefix |

The entries use absolute paths under `/home/vladkarok`. With another user
name, rewrite them while copying:

```bash
for f in applications/*.desktop; do
  sed "s|/home/vladkarok|$HOME|g" "$f" > ~/.local/share/applications/"${f##*/}"
done
update-desktop-database ~/.local/share/applications
```

### `etc/`

System files, mirroring their path under `/etc`. Need sudo.

- `etc/sysctl.d/40-disable-ipv6.conf`: turns IPv6 off. The home network has no
  working IPv6, and dead AAAA routes made Wine and Proton apps (the Last War
  launcher) stall on IPv6 connects. Drop it on a network with real IPv6.

```bash
sudo install -Dm644 etc/sysctl.d/40-disable-ipv6.conf /etc/sysctl.d/40-disable-ipv6.conf
sudo sysctl --system
```

### `hardware/`: specific to this laptop

Everything here depends on this machine's hardware (hybrid Intel/NVIDIA,
2560x1600 panel, Intel Wi-Fi, a Windows 11 VM with the dGPU passed through).
On other hardware, read each file and adjust it or skip it.

#### `hardware/hypr/monitors.lua`

Scale 2 for every monitor without a panel choice. Copy to
`~/.config/hypr/monitors.lua`. Change `omarchy_monitor_scale` for another
panel, or leave Omarchy's default and set the scale from the monitor panel.

#### `hardware/voxtype/gpu.conf`

Drop-in for the voxtype user service that pins Vulkan and GPU device index 1
(`VOXTYPE_VULKAN_DEVICE=1`, `VOXTYPE_GPU_DEVICE=1`). The index depends on the
GPU order; check it with `vulkaninfo --summary`.

A fresh Omarchy 4.5 install makes Superwhisper the dictation backend. Omarchy's `omarchy-install-dictation-voxtype` writes the voxtype unit, enables it and switches the backend to voxtype, so install the drop-in first. It copies Omarchy's default `~/.config/voxtype/config.toml` only when that file is missing. This repo does not track a voxtype config, so a fresh machine starts from that default.

```bash
install -Dm644 hardware/voxtype/gpu.conf ~/.config/systemd/user/voxtype.service.d/gpu.conf
omarchy-install-dictation-voxtype </dev/null   # unit, service, backend; reloads Hyprland
omarchy-remove-dictation-superwhisper          # only if superwhisper-bin is installed
# after later drop-in changes:
systemctl --user daemon-reload && systemctl --user restart voxtype
```

#### `hardware/looking-glass/`

Looking Glass into the Windows 11 libvirt VM through the kvmfr shared-memory
device. Install `looking-glass` and `looking-glass-module-dkms` from the AUR
first (see `aur-packages.txt`).

| File | Goes to | sudo |
| --- | --- | --- |
| `kvmfr-modprobe.conf` | `/etc/modprobe.d/kvmfr.conf` (`static_size_mb=64`) | yes |
| `kvmfr-modules-load.conf` | `/etc/modules-load.d/kvmfr.conf` (load kvmfr at boot) | yes |
| `99-kvmfr.rules` | `/etc/udev/rules.d/99-kvmfr.rules` (`/dev/kvmfr0` to group `kvm`, mode 0660) | yes |
| `qemu.conf.snippet` | append to `/etc/libvirt/qemu.conf` (adds `/dev/kvmfr0` to `cgroup_device_acl`) | yes |
| `vfio.conf.disabled` | `/etc/modprobe.d/vfio.conf.disabled`, kept off; rename to `.conf` to bind the dGPU (`10de:28e0`) and its audio (`10de:22be`) to vfio-pci at boot | yes |
| `looking-glass-win11` | `~/.local/bin/` (client on `/dev/kvmfr0`, F12 as the escape key, raw mouse, auto-capture) | no |
| `looking-glass-win11.desktop` | `~/.local/share/applications/` | no |
| `looking-glass-client.desktop` | `~/.local/share/applications/` (hides the AUR client's entry) | no |
| `win11.xml` | `virsh define` after filling the placeholders (below) | no |

The AUR client (B7-8) does not talk to the host version in the VM, which is
why its entry is hidden. `looking-glass-win11` runs a client built from
source at `B7-758-90c898f9`, saved as `~/.local/bin/looking-glass-client-b7-758`;
the binary is not in this repo. Build the client from the
[Looking Glass repo](https://github.com/gnif/LookingGlass) at the commit that
matches the host installed in Windows.

The user must be in the `kvm` and `libvirt` groups.

`win11.xml` is the VM definition (`virsh dumpxml --inactive win11`), scrubbed:
q35 with Secure Boot OVMF and an emulated TPM, host-passthrough CPU as 1 socket
x 4 cores x 2 threads, 12 GiB RAM, the Hyper-V enlightenments (custom mode,
including `evmcs` and `avic`), a virtio disk at
`/var/lib/libvirt/images/win11.qcow2`, and two NICs (libvirt's `default` and a
host-only `vm-local` network, which is not in this repo). Fill these
placeholders before `virsh -c qemu:///system define hardware/looking-glass/win11.xml`:

| Placeholder | Fill with |
| --- | --- |
| `@DOMAIN_UUID@` | a UUID (`uuidgen`), or delete the `<uuid>` line |
| `@MAC_DEFAULT_NET@`, `@MAC_VM_LOCAL_NET@` | `52:54:00:xx:xx:xx` MACs, or delete the `<mac>` lines for random ones |
| `@VIRTIO_WIN_ISO@` | the virtio-win driver ISO, or delete that cdrom `<disk>` |

The definition as it stands has no Looking Glass device, no GPU `<hostdev>`,
no CPU pinning and no hugepages: the kvmfr module is loaded but the running VM
does not open `/dev/kvmfr0`. To use Looking Glass again, add
`xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'` to `<domain>` and
this block before `</domain>` (64 MiB, matching `static_size_mb=64`), as the
Looking Glass docs describe:

```xml
<qemu:commandline>
  <qemu:arg value='-device'/>
  <qemu:arg value='{"driver":"ivshmem-plain","id":"shmem0","memdev":"looking-glass"}'/>
  <qemu:arg value='-object'/>
  <qemu:arg value='{"qom-type":"memory-backend-file","id":"looking-glass","mem-path":"/dev/kvmfr0","size":67108864,"share":true}'/>
</qemu:commandline>
```

```bash
sudo install -Dm644 hardware/looking-glass/kvmfr-modprobe.conf /etc/modprobe.d/kvmfr.conf
sudo install -Dm644 hardware/looking-glass/kvmfr-modules-load.conf /etc/modules-load.d/kvmfr.conf
sudo install -Dm644 hardware/looking-glass/99-kvmfr.rules /etc/udev/rules.d/99-kvmfr.rules
sudo tee -a /etc/libvirt/qemu.conf < hardware/looking-glass/qemu.conf.snippet >/dev/null
install -Dm755 hardware/looking-glass/looking-glass-win11 ~/.local/bin/looking-glass-win11
for f in hardware/looking-glass/*.desktop; do
  sed "s|/home/vladkarok|$HOME|g" "$f" > ~/.local/share/applications/"${f##*/}"
done
sudo modprobe kvmfr && sudo systemctl restart libvirtd
```

### `aur-packages.txt` and `repo-packages.txt`

Package lists for a fresh install. `aur-packages.txt` is `pacman -Qm` without
the packages that only come in as dependencies. `repo-packages.txt` is the
explicitly installed repo packages that are not in Omarchy's own package
lists, grouped, with notes on the less obvious ones. Both have the install
command in their header. Each ends with a commented-out "Probably removable"
block (`wvkbd`, `lib32-sdl2-compat`, `walker`): nothing on this machine uses
them, the install command skips them, and the block has the `pacman -Rns` line
for each. `libjpeg6-turbo` stays: Viber's bundled `libtiff.so.5` needs
`libjpeg.so.62`, which no declared dependency provides.

### Other repositories

These live elsewhere and are referenced, not copied:

- [Vladkarok/lwupdate](https://github.com/Vladkarok/lwupdate) (private): the
  Last War launcher, installer and update scripts. `applications/LastWar.desktop`
  expects it at `~/Work/lwupdate`. The older `~/.local/bin/lastwar-launch` and
  `lastwar-install` are superseded by it.
- [Vladkarok/omasnap](https://github.com/Vladkarok/omasnap), branch `patched`:
  the patched omasnap. Build it and put the binary in `~/.local/bin/omasnap`,
  where it shadows the packaged `omasnap`.
- [Vladkarok/wine-thumbs](https://github.com/Vladkarok/wine-thumbs): the Wine
  patches.
- [Vladkarok/oskar](https://github.com/Vladkarok/oskar): the on-screen
  keyboard. `omarchy plugin add https://github.com/Vladkarok/oskar --enable`
  installs the plugin (this machine links a development clone instead), and
  the repo's `install.sh` installs the daemon to `~/.local/libexec/oskar-daemon`
  and writes and enables `~/.config/systemd/user/oskar.service`. Nothing of it
  is copied here.
- [Vladkarok/omabump](https://github.com/Vladkarok/omabump): the update-check
  bar plugin. Clone it and link it to
  `~/.config/omarchy/plugins/io.github.vladkarok.omabump`.

## Bootstrap a fresh Omarchy 4.x machine

Install Omarchy 4.x, finish its first-run setup, clone this repo, then:

```bash
./bootstrap.sh                   # dry run: prints every action, changes nothing
./bootstrap.sh --apply           # do it (from a normal terminal, for sudo)
./bootstrap.sh --list            # the steps
./bootstrap.sh --only hypr,shell # some steps only
./bootstrap.sh --with-hardware   # also the hw-* steps, for this laptop only
```

It runs the per-directory installs above in order: the sudo steps first
(`packages`, `local-patched-repo`, `etc-sysctl`, `snapper`, and with
`--with-hardware` `hw-looking-glass`), then `hypr`, `terminals`,
`shell`, `env`, `mise`, `applications`, `local-bin`, `omarchy-bin`,
`omarchy-shell` and `hw-monitors`, `hw-voxtype`. It is safe to re-run. A
target that matches the repo is left alone; one that differs is saved as
`<target>.bak.<timestamp>` first. `~/.config/omarchy/shell.json` is only
written when it is missing, because the shell rewrites it; when it differs, the run says so and prints the command that takes the repo copy. Templates
(`rdp-connect.env.example`, the Remmina examples) are copied as `*.example`
next to their target, and only when the real file is not there yet.
`win11.xml` is not copied. The `zai-second` collector timer is installed but
not enabled. Nothing under `/usr/share/omarchy` is touched.

`local-patched-repo` also installs the patched `remmina` and `hyprpm`; log out
and back in afterwards. The run ends with a list of reminders. Still by hand:

- The Hyprland `monitors.lua`: `hw-monitors` on this laptop, otherwise
  Omarchy's own or one with the right scale.
- OSKar and omabump from their repos, and wallpapers in the theme's
  `backgrounds/`.
- Templates: `~/.config/rdp-connect.env`, Remmina's `remmina.pref` and
  profile, `win11.xml` (see `hardware/looking-glass/`).
- Agent usage: log in to Grok, and put the primary Z.ai key as `apiKey` in
  `~/.config/omarchy/agents/zai.json` (mode 0600) or export `ZAI_API_KEY`;
  Omarchy's own collectors do the rest. For the second Z.ai account run
  `omarchy-zai-account add second`, then
  `systemctl --user enable --now omarchy-agent-usage-zai-second.timer`.
- Looking Glass: build the matching client, define the VM (add the kvmfr
  block), restart libvirtd.
- Projects from other repositories: clone `lwupdate` to `~/Work/lwupdate`
  for Last War, build the `omasnap` fork into `~/.local/bin/omasnap`, and
  apply the `wine-thumbs` patches if needed. agterm from its tarball.
- Things to check rather than copy:
  - Idle and lock timings live in `~/.config/omarchy/shell.json`
    (`idle.lock`, `idle.screensaver`). `hypridle` and `hyprlock` are not
    installed on Omarchy 4, so their old config files have no effect; the
    lock screen is the Lock Explorer plugin.
  - fcitx5 ships with Omarchy and runs. Keep `~/.config/fcitx5/profile` to the single `keyboard-us` item; adding the UA layout there breaks Ctrl+C and Ctrl+V in fcitx5 apps.
  - `omarchy-refresh-limine` replaces `/boot/limine.conf`. Re-add
    `remember_last_entry: yes` afterwards.
  - Do not put multi-line secrets in the empty-password GNOME keyring. It
    stores them unescaped and the next daemon start fails to load the
    keyring; store them base64-encoded on one line. If the keyring is ever
    broken, fix it before opening a Chromium browser, which deletes cookies it
    cannot decrypt.
  - Take Omarchy's versions of git, tmux, fastfetch and btop
    config; the old copies were only stale defaults.
  - Known unsolved: after resume the NumLock LED reads on but the numpad types
    nothing until NumLock is toggled twice (hyprlock #680).

## Checked and left out

These exist on the machine but come from Omarchy, a package, or another
installer, so a fresh install recreates them:

- `/etc/modprobe.d/nvidia.conf` (`nvidia_drm modeset=1`): Omarchy's
  `install/hardware/nvidia.sh`.
- `/etc/modprobe.d/hid_apple.conf` (`fnmode=2`): Omarchy's `fix-fkeys.sh`.
- `/etc/modprobe.d/disable-usb-autosuspend.conf`: Omarchy's old
  `usb-autosuspend.sh`; the package now ships `omarchy-usb-autosuspend.conf`
  with the same option.
- `/etc/sysctl.d/99-sysctl.conf` (`tcp_mtu_probing=1`): Omarchy's old
  `ssh-flakiness.sh`; now in the packaged `99-omarchy-sysctl.conf`.
- `/etc/systemd/system/user@.service.d/faster-shutdown.conf`: identical to
  Omarchy's default, which the package now ships as `10-faster-shutdown.conf`.
- `~/.config/environment.d/omarchy-firefox-wayland.conf`: written by
  `omarchy-install-browser`.
- `~/.config/hypr/hypridle.conf`, `hyprlock.conf`: left over from Omarchy 3;
  neither program is installed on 4.x.
- `~/.config/systemd/user/voxtype.service`: written by `voxtype setup systemd`, which `omarchy-install-dictation-voxtype` runs.
- `~/.local/share/applications/anydesk.desktop`: written by the AnyDesk hook in
  `anydesk/`. `typora.desktop`, `windows-vm.desktop`, `battlenet.desktop`,
  `Docker.desktop`, the web apps and the 28-byte hidden entries: written by
  Omarchy. `xclicker.desktop`: identical to the package's. The T3 Code and
  GeForce NOW entries: written by those apps' installers.
- `~/.local/bin/kimi`, `playwright-cli`: wrappers generated by
  `omarchy-mise-install`. `anydesk-100scale`: written by the AnyDesk hook.
  `env`, `env.fish`, `uv`, `uvx`: the uv installer. `agterm`, `markitdown`,
  `UnityPy`, `t3`, `revmux`: links to other installs.
- `~/.config/omarchy/hooks/theme-set`, `theme-set.d/10-owe-sync`,
  `post-update.d/setup-agent.hook`: see `omarchy/shell/` above.

Removed from the machine in 2026-11 (moved to the trash, not captured):

- `oskar-seat-watch.service`: an OSKar development diagnostic that ran a
  script from the clone's `.scratch/` directory to catch a Hyprland seat bug.
  The local Hyprland patches in `hyprland/` fix that bug. `oskar.service` did
  not depend on it.
- `~/.local/bin/whatsapp-linux-desktop`: a symlink into the removed
  `/opt/WhatsApp Desktop`; ZapZap replaced it.
- `~/.local/share/applications/omamail.desktop`: pointed at the omamail plugin,
  which is no longer installed.
- `~/.local/bin/record-all-screens`: its start/stop toggle never worked (the
  script exits right after starting the recorder, so a second run cannot find
  the first). Omarchy's own screen recording covers region and monitor
  capture.

## Not captured yet

- `~/.config/omarchy/agents/` (including `zai.json`): API keys. Never commit;
  recreate with `omarchy-zai-account add <label>` and the agents' own logins.
- `~/.local/bin/looking-glass-client-b7-758`: a binary; build it as described
  under `hardware/looking-glass/`.
- The `vm-local` libvirt network that `win11.xml` uses (an isolated network,
  no forwarding, with its own subnet and DHCP). Recreate it in virt-manager or
  drop that NIC.
- The `neutral-dark` wallpapers (about 4.7 MB of images).

## License

MIT
