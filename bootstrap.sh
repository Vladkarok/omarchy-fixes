#!/usr/bin/env bash
# Apply this repo to a freshly installed Omarchy 4.x machine.
#
#   ./bootstrap.sh                      # dry run of the default steps (changes nothing)
#   ./bootstrap.sh --apply              # do it
#   ./bootstrap.sh --list               # show the steps
#   ./bootstrap.sh --only hypr,shell    # just these steps (dry run unless --apply)
#   ./bootstrap.sh --with-hardware      # also the hw-* steps (specific to one laptop)
#
# Safe to re-run: a target that already matches the repo copy is skipped
# (cmp), and one that differs is saved as <target>.bak.<timestamp> before it
# is overwritten. Steps that need sudo run first, as one group, and sudo is
# only called with --apply. Nothing under /usr/share/omarchy is touched, and
# no secrets are written: templates with placeholders are copied as
# *.example next to their target, with a reminder to fill them in.

set -euo pipefail

REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
TS=$(date +%Y%m%d-%H%M%S)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

APPLY=0
WITH_HW=0
LIST=0
ONLY=""

# name|sudo|hw|description. Order is run order: the sudo group comes first.
STEPS=(
  "packages|sudo||repo-packages.txt with pacman, aur-packages.txt with yay; drop the pacman herdr"
  "local-patched-repo|sudo||build hyprland/ and remmina/ if needed, then pacman/local-patched-repo/install.sh"
  "etc-sysctl|sudo||etc/sysctl.d/40-disable-ipv6.conf"
  "snapper|sudo||snapper config for /home and snapper-home.timer"
  "hw-wifi|sudo|hw|hardware/wifi udev rule (Wi-Fi power save off)"
  "hw-looking-glass|sudo|hw|hardware/looking-glass: kvmfr, qemu.conf ACL, client launcher"
  "hypr|||hypr/*.lua and hyprsunset.conf to ~/.config/hypr"
  "terminals|||alacritty, foot, ghostty, kitty configs"
  "shell|||zshrc, zsh_aliases, p10k.zsh and the zsh plugins they source"
  "env|||environment.d, pacman/makepkg.conf, chatgpt/codex-flags.conf"
  "mise|||mise/global-config.toml and mise install"
  "applications|||desktop overrides (claude, viber, agterm, remmina, applications/), Yaru-gray link, AnyDesk hook"
  "local-bin|||local-bin/ scripts to ~/.local/bin"
  "omarchy-bin|||omarchy/bin and omarchy/systemd (usage collectors, brightness)"
  "omarchy-shell|||shell plugins, omarchy/shell/, neutral-dark theme"
  "hw-monitors||hw|hardware/hypr/monitors.lua (scale 2)"
  "hw-voxtype||hw|hardware/voxtype GPU drop-in"
)

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  echo
  echo "Options: --apply  --dry-run (default)  --only <step>[,<step>]  --with-hardware  --list  -h"
}

while (($#)); do
  case $1 in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    --with-hardware) WITH_HW=1 ;;
    --list) LIST=1 ;;
    --only)
      [[ $# -ge 2 ]] || { echo "--only needs a step list" >&2; exit 2; }
      ONLY=$2
      shift
      ;;
    --only=*) ONLY=${1#--only=} ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

step_field() { # step_field <entry> <1-4>
  local f
  IFS='|' read -r -a f <<<"$1"
  printf '%s' "${f[$(($2 - 1))]:-}"
}

if ((LIST)); then
  for e in "${STEPS[@]}"; do
    flags=""
    [[ $(step_field "$e" 2) == sudo ]] && flags+=" [sudo]"
    [[ $(step_field "$e" 3) == hw ]] && flags+=" [hardware, needs --with-hardware]"
    printf '%-20s %s%s\n' "$(step_field "$e" 1)" "$(step_field "$e" 4)" "$flags"
  done
  exit 0
fi

# ---- choose steps --------------------------------------------------------

declare -A KNOWN=()
for e in "${STEPS[@]}"; do KNOWN[$(step_field "$e" 1)]=$e; done

declare -A WANT=()
if [[ -n $ONLY ]]; then
  IFS=',' read -ra picked <<<"$ONLY"
  for s in "${picked[@]}"; do
    [[ -n ${KNOWN[$s]:-} ]] || { echo "Unknown step: $s (see --list)" >&2; exit 2; }
    if [[ $(step_field "${KNOWN[$s]}" 3) == hw ]] && ((!WITH_HW)); then
      echo "$s is a hardware step; add --with-hardware to run it." >&2
      exit 2
    fi
    WANT[$s]=1
  done
fi

SELECTED=()
for e in "${STEPS[@]}"; do
  name=$(step_field "$e" 1)
  if [[ -n $ONLY ]]; then
    [[ -n ${WANT[$name]:-} ]] && SELECTED+=("$e")
  elif [[ $(step_field "$e" 3) != hw ]] || ((WITH_HW)); then
    SELECTED+=("$e")
  fi
done

# ---- output and action helpers -------------------------------------------

N_UNCHANGED=0 N_NEW=0 N_UPDATE=0
DRIFT=() # targets that exist and differ from the repo
NOTES=() # reminders printed at the end
CHANGED=0 # set by place/link when the current step changes (or would change) something

say() { printf '%s\n' "$*"; }
note() { NOTES+=("$*"); }
quote() { printf '%q ' "$@"; }

# run <cmd...>: print it; run it only with --apply.
run() {
  if ((APPLY)); then
    say "  run: $(quote "$@")"
    "$@"
  else
    say "  would run: $(quote "$@")"
  fi
}

# place [--sudo] [--seed] <mode> <src> <dst>
#   --sudo  target is root-owned; install and back up with sudo
#   --seed  file the app rewrites itself: install only when missing, never overwrite
place() {
  local sudo=() seed=0
  while [[ $1 == --* ]]; do
    case $1 in
      --sudo) sudo=(sudo) ;;
      --seed) seed=1 ;;
    esac
    shift
  done
  local mode=$1 src=$2 dst=$3
  [[ -f $src ]] || { say "  MISSING in repo: $src" >&2; return 1; }

  if [[ -e $dst ]]; then
    if [[ ! -r $dst ]]; then
      say "  unreadable (needs sudo to compare), will back up and replace: $dst"
      DRIFT+=("$dst (unreadable)")
    elif cmp -s "$src" "$dst"; then
      # Same content: leave it alone, even when the mode differs.
      local cur
      cur=$(stat -Lc %a "$dst")
      if [[ $cur == "$mode" ]]; then
        say "  unchanged  $dst"
      else
        say "  unchanged  $dst (mode $cur, the repo would install $mode; left as is)"
        DRIFT+=("$dst (mode $cur, not $mode)")
      fi
      N_UNCHANGED=$((N_UNCHANGED + 1))
      return 0
    elif ((seed)); then
      say "  kept (differs, app-owned; not overwritten)  $dst"
      DRIFT+=("$dst (kept, seed only)")
      N_UNCHANGED=$((N_UNCHANGED + 1))
      return 0
    else
      say "  differs    $dst"
      DRIFT+=("$dst")
    fi
    run "${sudo[@]}" cp -a -- "$dst" "$dst.bak.$TS"
    # install(1) writes through a symlink; replace the link, not its target.
    [[ -L $dst ]] && run "${sudo[@]}" rm -- "$dst"
    N_UPDATE=$((N_UPDATE + 1))
  else
    say "  new        $dst"
    N_NEW=$((N_NEW + 1))
  fi
  run "${sudo[@]}" install -D -m "$mode" -- "$src" "$dst"
  CHANGED=1
}

# render <src>: copy of src with /home/vladkarok replaced by $HOME, for
# desktop entries that carry absolute paths. Prints the temp path.
render() {
  local out
  out="$TMP/$(printf '%s' "$1" | tr '/' '_')"
  sed "s|/home/vladkarok|$HOME|g" "$1" >"$out"
  printf '%s' "$out"
}

# link <target> <linkpath>
link() {
  local target=$1 path=$2
  if [[ -L $path && $(readlink "$path") == "$target" ]]; then
    say "  unchanged  $path -> $target"
    N_UNCHANGED=$((N_UNCHANGED + 1))
    return 0
  fi
  if [[ -e $path || -L $path ]]; then
    say "  differs    $path (now $(readlink "$path" || echo 'a file'))"
    DRIFT+=("$path")
    run mv -- "$path" "$path.bak.$TS"
    N_UPDATE=$((N_UPDATE + 1))
  else
    say "  new        $path -> $target"
    N_NEW=$((N_NEW + 1))
  fi
  run mkdir -p "$(dirname "$path")"
  run ln -s "$target" "$path"
  CHANGED=1
}

# example <src> <dst> <real> [<glob>] [<hint>]: placeholder template, copied
# to <dst> as an example only. Skipped when the real file (or a match of
# <glob>) is already there, since that one holds real values and is not
# compared.
example() {
  local src=$1 dst=$2 real=$3 glob=${4:-}
  if [[ -e $real ]] || { [[ -n $glob ]] && compgen -G "$glob" >/dev/null; }; then
    say "  unchanged  ${glob:-$real} exists (real values; not compared)"
    N_UNCHANGED=$((N_UNCHANGED + 1))
    return 0
  fi
  place 644 "$src" "$dst"
  note "Template only: copy $dst to $real, fill in the placeholders${5:+ ($5)}."
}

pkg_names() { # pkg_names <list-file>: first word of every non-comment line
  grep -v '^[[:space:]]*#' "$1" | awk 'NF { print $1 }'
}

missing_pkgs() { # names from stdin that pacman does not have installed
  local names=()
  mapfile -t names
  ((${#names[@]})) || return 0
  pacman -T -- "${names[@]}" || true
}

in_hyprland() { [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null; }

APPS=~/.local/share/applications
BIN=~/.local/bin

# ---- steps -----------------------------------------------------------------

step_packages() {
  local repo_missing aur_missing
  mapfile -t repo_missing < <(pkg_names "$REPO/repo-packages.txt" | missing_pkgs)
  mapfile -t aur_missing < <(pkg_names "$REPO/aur-packages.txt" | missing_pkgs)
  say "  repo-packages.txt: $(pkg_names "$REPO/repo-packages.txt" | wc -l) listed, ${#repo_missing[@]} not installed"
  ((${#repo_missing[@]})) && say "    ${repo_missing[*]}"
  say "  aur-packages.txt:  $(pkg_names "$REPO/aur-packages.txt" | wc -l) listed, ${#aur_missing[@]} not installed"
  ((${#aur_missing[@]})) && say "    ${aur_missing[*]}"
  # The commented "Probably removable" blocks are skipped by pkg_names.
  if ((${#repo_missing[@]})); then
    run sudo pacman -S --needed --noconfirm -- "${repo_missing[@]}"
  fi
  if ((${#aur_missing[@]})); then
    if command -v yay >/dev/null; then
      run yay -S --needed --noconfirm --answerdiff None --answerclean None -- "${aur_missing[@]}"
    else
      say "  yay not found; install the AUR packages by hand"
    fi
  fi
  # mise/ installs herdr; a pacman copy would shadow the mise shim.
  if pacman -Q herdr >/dev/null 2>&1; then
    run sudo pacman -Rns --noconfirm herdr
  else
    say "  unchanged  pacman herdr not installed (mise provides it)"
  fi
}

step_local_patched_repo() {
  local d=$REPO/pacman/local-patched-repo hooks=~/.config/omarchy/hooks
  local -a need_build=() unpublished=() f=()
  local name dir p
  shopt -s nullglob
  for name in hyprland hyprpm remmina; do
    dir=$REPO/hyprland
    [[ $name == remmina ]] && dir=$REPO/remmina
    f=("$dir/$name"-[0-9]*.pkg.tar.zst)
    if ((${#f[@]} == 0)); then
      need_build+=("$name")
    else
      # install.sh publishes the newest build of each package.
      p=$(printf '%s\n' "${f[@]}" | sort -V | tail -n 1)
      [[ -e /var/lib/local-patched-repo/${p##*/} ]] || unpublished+=("${p##*/}")
    fi
  done
  shopt -u nullglob

  if [[ " ${need_build[*]} " == *" hyprland "* || " ${need_build[*]} " == *" hyprpm "* ]]; then
    say "  no built hyprland/hyprpm package"
    (cd "$REPO/hyprland" && run makepkg -s --noconfirm)
  fi
  if [[ " ${need_build[*]} " == *" remmina "* ]]; then
    say "  no built remmina package"
    (cd "$REPO/remmina" && run makepkg -df --noconfirm)
  fi

  local configured=1
  cmp -s "$d/custom-repos.conf" /etc/pacman.d/custom-repos.conf || configured=0
  cmp -s "$d/10-local-patched-repo" "$hooks/pre-refresh-pacman.d/10-local-patched-repo" || configured=0
  cmp -s "$d/20-warn-shadowed-local-pkgs" "$hooks/post-update.d/20-warn-shadowed-local-pkgs" || configured=0
  [[ $(pacman-conf --repo-list 2>/dev/null | head -n 1) == local-patched ]] || configured=0

  if ((configured)) && ((${#need_build[@]} == 0)) && ((${#unpublished[@]} == 0)); then
    say "  unchanged  [local-patched] is the first repository; snippet, hooks and built packages are published"
    N_UNCHANGED=$((N_UNCHANGED + 1))
  else
    ((configured)) || say "  repository snippet, hooks or pacman.conf Include not in place"
    ((${#unpublished[@]})) && say "  built but not published: ${unpublished[*]}"
    # install.sh does the sudo work itself and refuses no-new-privileges shells.
    run bash "$d/install.sh"
    note "Run 'omarchy update' to install the [local-patched] builds, then log out and back in."
    CHANGED=1
  fi
  note "remmina/: the published build may trail extra (see README, 'Rebuild needed')."
}

step_etc_sysctl() {
  CHANGED=0
  place --sudo 644 "$REPO/etc/sysctl.d/40-disable-ipv6.conf" /etc/sysctl.d/40-disable-ipv6.conf
  ((CHANGED)) && run sudo sysctl --system
  return 0
}

step_snapper() {
  CHANGED=0
  if [[ -e /etc/snapper/configs/home ]]; then
    say "  unchanged  snapper config 'home' exists"
    N_UNCHANGED=$((N_UNCHANGED + 1))
  else
    say "  new        snapper config 'home'"
    run sudo snapper -c home create-config /home
    run sudo snapper -c home set-config TIMELINE_CREATE=no TIMELINE_LIMIT_HOURLY=12 \
      TIMELINE_LIMIT_DAILY=7 TIMELINE_LIMIT_WEEKLY=2 TIMELINE_LIMIT_MONTHLY=0 \
      TIMELINE_LIMIT_YEARLY=0 TIMELINE_MIN_AGE=1800 NUMBER_LIMIT=5 \
      "ALLOW_USERS=$USER" SYNC_ACL=yes
  fi
  place --sudo 644 "$REPO/snapper/snapper-home.service" /etc/systemd/system/snapper-home.service
  place --sudo 644 "$REPO/snapper/snapper-home.timer" /etc/systemd/system/snapper-home.timer
  ((CHANGED)) && run sudo systemctl daemon-reload
  if systemctl is-enabled --quiet snapper-home.timer 2>/dev/null; then
    say "  unchanged  snapper-home.timer enabled"
  else
    run sudo systemctl enable --now snapper-home.timer
  fi
}

step_hw_wifi() {
  CHANGED=0
  place --sudo 644 "$REPO/hardware/wifi/70-wifi-powersave-off.rules" /etc/udev/rules.d/70-wifi-powersave-off.rules
  ((CHANGED)) && run sudo udevadm control --reload
  return 0
}

step_hw_looking_glass() {
  local lg=$REPO/hardware/looking-glass sys=0 f
  CHANGED=0
  place --sudo 644 "$lg/kvmfr-modprobe.conf" /etc/modprobe.d/kvmfr.conf
  place --sudo 644 "$lg/kvmfr-modules-load.conf" /etc/modules-load.d/kvmfr.conf
  place --sudo 644 "$lg/99-kvmfr.rules" /etc/udev/rules.d/99-kvmfr.rules
  place --sudo 644 "$lg/vfio.conf.disabled" /etc/modprobe.d/vfio.conf.disabled
  ((CHANGED)) && sys=1

  local qconf=/etc/libvirt/qemu.conf
  if [[ ! -e $qconf ]]; then
    say "  skipped    $qconf missing (install libvirt first)"
  elif [[ ! -r $qconf ]]; then
    say "  unreadable $qconf; check for /dev/kvmfr0 in cgroup_device_acl by hand"
  elif grep -q '^[[:space:]]*"/dev/kvmfr0"' "$qconf"; then
    say "  unchanged  $qconf already lists /dev/kvmfr0"
    N_UNCHANGED=$((N_UNCHANGED + 1))
  else
    say "  append     $qconf (cgroup_device_acl with /dev/kvmfr0)"
    run sudo cp -a -- "$qconf" "$qconf.bak.$TS"
    if ((APPLY)); then
      sudo tee -a "$qconf" <"$lg/qemu.conf.snippet" >/dev/null
    else
      say "  would run: sudo tee -a $qconf < hardware/looking-glass/qemu.conf.snippet"
    fi
    sys=1
  fi

  place 755 "$lg/looking-glass-win11" "$BIN/looking-glass-win11"
  for f in "$lg"/*.desktop; do
    place 644 "$(render "$f")" "$APPS/${f##*/}"
  done

  if ((sys)); then
    run sudo modprobe kvmfr
    run sudo udevadm control --reload
    note "Restart libvirtd (sudo systemctl restart libvirtd) when no VM is running, for the qemu.conf change."
  fi
  local missing_groups=()
  for g in kvm libvirt; do
    id -nG | tr ' ' '\n' | grep -qx "$g" || missing_groups+=("$g")
  done
  if ((${#missing_groups[@]})); then
    run sudo usermod -aG "$(IFS=,; echo "${missing_groups[*]}")" "$USER"
    note "Log out and back in for the new groups: ${missing_groups[*]}."
  else
    say "  unchanged  $USER is in kvm and libvirt"
  fi
  [[ -x $BIN/looking-glass-client-b7-758 ]] ||
    note "Build the Looking Glass client into ~/.local/bin/looking-glass-client-b7-758 (README, hardware/looking-glass/)."
  note "hardware/looking-glass/win11.xml is a template: fill @DOMAIN_UUID@, @MAC_*@, @VIRTIO_WIN_ISO@ before 'virsh define'. Not copied."
}

step_hypr() {
  local f
  CHANGED=0
  for f in "$REPO"/hypr/*.lua "$REPO/hypr/hyprsunset.conf"; do
    place 644 "$f" ~/.config/hypr/"${f##*/}"
  done
  [[ -e ~/.config/hypr/monitors.lua ]] ||
    note "~/.config/hypr/monitors.lua is missing and hyprland.lua requires it: run the hw-monitors step or create one."
  if ((CHANGED)) && in_hyprland; then
    run hyprctl reload
    run hyprctl configerrors
  fi
  return 0
}

step_terminals() {
  place 644 "$REPO/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml
  place 644 "$REPO/foot/foot.ini" ~/.config/foot/foot.ini
  place 644 "$REPO/ghostty/config" ~/.config/ghostty/config
  place 644 "$REPO/kitty/kitty.conf" ~/.config/kitty/kitty.conf
}

step_shell() {
  place 644 "$REPO/shell/zshrc" ~/.zshrc
  place 644 "$REPO/shell/zsh_aliases" ~/.zsh_aliases
  place 644 "$REPO/shell/p10k.zsh" ~/.p10k.zsh
  local custom=~/.oh-my-zsh/custom entry url dir
  # zshrc sources these paths directly.
  for entry in \
    "https://github.com/zsh-users/zsh-autosuggestions|plugins/zsh-autosuggestions" \
    "https://github.com/zdharma-continuum/fast-syntax-highlighting.git|plugins/fast-syntax-highlighting" \
    "https://github.com/romkatv/powerlevel10k.git|themes/powerlevel10k"; do
    url=${entry%%|*}
    dir=$custom/${entry#*|}
    if [[ -d $dir ]]; then
      say "  unchanged  $dir"
      N_UNCHANGED=$((N_UNCHANGED + 1))
    else
      say "  new        $dir"
      N_NEW=$((N_NEW + 1))
      run git clone --depth 1 "$url" "$dir"
    fi
  done
  local tools=() t
  for t in zoxide fzf fnm eza bat broot nvim; do
    command -v "$t" >/dev/null || tools+=("$t")
  done
  ((${#tools[@]})) && note "zshrc expects these commands, not found: ${tools[*]}."
  return 0
}

step_env() {
  CHANGED=0
  place 644 "$REPO/environment.d/electron-wayland.conf" ~/.config/environment.d/electron-wayland.conf
  ((CHANGED)) && note "environment.d changed: log out and back in."
  place 644 "$REPO/pacman/makepkg.conf" ~/.config/pacman/makepkg.conf
  place 644 "$REPO/chatgpt/codex-flags.conf" ~/.config/codex-flags.conf
}

step_mise() {
  CHANGED=0
  place 644 "$REPO/mise/global-config.toml" ~/.config/mise/config.toml
  if ! command -v mise >/dev/null; then
    say "  mise not found; skipping mise install"
  elif ((CHANGED)) || ! mise where herdr >/dev/null 2>&1; then
    run mise install
  else
    say "  unchanged  mise tools from the global config are installed"
  fi
}

step_applications() {
  local f
  CHANGED=0
  for f in "$REPO/claude/com.anthropic.Claude.desktop" "$REPO/viber/viber.desktop" \
    "$REPO/agterm/io.github.melonamin.agterm.desktop" "$REPO/remmina/org.remmina.Remmina.desktop" \
    "$REPO"/applications/*.desktop; do
    place 644 "$(render "$f")" "$APPS/${f##*/}"
  done
  ((CHANGED)) && run update-desktop-database "$APPS"

  # Remmina tray icon: Omarchy themes name Yaru-gray, which nothing ships.
  link /usr/share/icons/Yaru-dark ~/.local/share/icons/Yaru-gray

  # Remmina templates: copied next to the real files, never over them.
  example "$REPO/remmina/remmina.pref.example" ~/.config/remmina/remmina.pref.example \
    ~/.config/remmina/remmina.pref "" "with Remmina closed"
  example "$REPO/remmina/rdp-profile.example.remmina" ~/.config/remmina/rdp-profile.example.remmina \
    ~/.local/share/remmina/rdp-profile.remmina "$HOME/.local/share/remmina/*.remmina" "with Remmina closed"

  if command -v anydesk >/dev/null; then
    CHANGED=0
    local hook=~/.config/omarchy/hooks/post-update.d/anydesk-100scale
    place 755 "$REPO/anydesk/anydesk-100scale-post-update" "$hook"
    ((CHANGED)) && run "$hook"
  else
    say "  skipped    AnyDesk hook (anydesk not installed)"
  fi
  [[ -x $BIN/agterm ]] || note "agterm has no package: install the tarball as in agterm/README.md."
  return 0
}

step_local_bin() {
  local f
  for f in rdp-connect opencode-npx xclicker-wrapper; do
    place 755 "$REPO/local-bin/$f" "$BIN/$f"
  done
  example "$REPO/local-bin/rdp-connect.env.example" ~/.config/rdp-connect.env.example \
    ~/.config/rdp-connect.env "" "chmod 600; no password"
  return 0
}

step_omarchy_bin() {
  local f
  CHANGED=0
  for f in "$REPO"/omarchy/bin/*; do
    place 755 "$f" "$BIN/${f##*/}"
  done
  for f in "$REPO"/omarchy/systemd/*; do
    place 644 "$f" ~/.config/systemd/user/"${f##*/}"
  done
  ((CHANGED)) && run systemctl --user daemon-reload
  local t
  for t in omarchy-agent-usage-grok.timer omarchy-agent-usage-zai.timer; do
    if systemctl --user is-enabled --quiet "$t" 2>/dev/null; then
      say "  unchanged  $t enabled"
    else
      note "$t is not enabled. Add the key/login first (README, omarchy/), then: systemctl --user enable --now $t"
    fi
  done
  note "omarchy/patches/notification-toast-layer-crash.patch patches /usr/share/omarchy; bootstrap does not apply it."
}

step_omarchy_shell() {
  local entry url id ids="" theme_dir=~/.config/omarchy/themes/neutral-dark f
  if command -v omarchy >/dev/null; then
    ids=$(timeout 30 omarchy plugin list </dev/null 2>/dev/null | awk 'NR > 1 { print $1 }') || true
  fi
  for entry in \
    "https://github.com/AksharP5/omarchy-radio-atlas.git|akshar.radio-atlas" \
    "https://github.com/glafeara/omarchy-wireguard.git|glafeara.wireguard" \
    "https://github.com/SirJul1337/omarchy-lock-explorer.git|io.github.sirjul1337.lock-explorer" \
    "https://github.com/stappmus/omarchy-activity-monitor.git|stappmus.activity-monitor"; do
    url=${entry%%|*}
    id=${entry#*|}
    if grep -qx "$id" <<<"$ids"; then
      say "  unchanged  plugin $id"
      N_UNCHANGED=$((N_UNCHANGED + 1))
    else
      say "  new        plugin $id"
      N_NEW=$((N_NEW + 1))
      run omarchy plugin add "$url" --yes
    fi
  done
  for id in io.github.vladkarok.omabump io.github.vladkarok.oskar; do
    grep -qx "$id" <<<"$ids" ||
      note "Plugin $id is linked from a clone (README, 'Other repositories'); not installed."
  done

  # The shell rewrites shell.json; only seed it.
  place --seed 600 "$REPO/omarchy/shell/shell.json" ~/.config/omarchy/shell.json
  place 644 "$REPO/omarchy/shell/shell.toml" ~/.config/omarchy/shell.toml
  for f in "$REPO"/omarchy/themes/neutral-dark/*; do
    place 644 "$f" "$theme_dir/${f##*/}"
  done
  [[ -d $theme_dir/backgrounds ]] || run mkdir -p "$theme_dir/backgrounds"
  compgen -G "$theme_dir/backgrounds/*" >/dev/null ||
    note "Add wallpapers to $theme_dir/backgrounds/ (not in the repo)."

  local current=""
  command -v omarchy >/dev/null &&
    current=$(timeout 10 omarchy theme current </dev/null 2>/dev/null | tr '[:upper:] ' '[:lower:]-') || true
  if [[ $current == neutral-dark ]]; then
    say "  unchanged  theme neutral-dark is current"
  else
    run omarchy theme set neutral-dark
  fi
}

step_hw_monitors() {
  CHANGED=0
  place 644 "$REPO/hardware/hypr/monitors.lua" ~/.config/hypr/monitors.lua
  ((CHANGED)) && in_hyprland && run hyprctl reload
  return 0
}

step_hw_voxtype() {
  local unit=~/.config/systemd/user/voxtype.service
  CHANGED=0
  if [[ ! -e $unit ]]; then
    if command -v voxtype >/dev/null; then
      run voxtype setup systemd
    else
      say "  skipped    voxtype not installed"
      return 0
    fi
  fi
  place 644 "$REPO/hardware/voxtype/gpu.conf" ~/.config/systemd/user/voxtype.service.d/gpu.conf
  if ((CHANGED)); then
    run systemctl --user daemon-reload
    run systemctl --user restart voxtype
  fi
  note "voxtype GPU index 1 is this laptop's order; check with 'vulkaninfo --summary'."
}

# ---- main ------------------------------------------------------------------

((${#SELECTED[@]})) || { echo "No steps selected." >&2; exit 2; }

if ((APPLY)); then
  say "Mode: APPLY"
else
  say "Mode: dry run (nothing is changed; pass --apply to do it)"
fi
say "Repo: $REPO"

sudo_steps=()
for e in "${SELECTED[@]}"; do
  [[ $(step_field "$e" 2) == sudo ]] && sudo_steps+=("$(step_field "$e" 1)")
done
if ((${#sudo_steps[@]})); then
  say "Steps that use sudo (run first, together): ${sudo_steps[*]}"
  if ((APPLY)); then
    if grep -q '^NoNewPrivs:[[:space:]]*1' /proc/self/status; then
      echo "This shell has no-new-privileges set, so sudo cannot work. Run from a normal terminal, or leave out: ${sudo_steps[*]}" >&2
      exit 1
    fi
    sudo -v
  fi
fi

for e in "${SELECTED[@]}"; do
  name=$(step_field "$e" 1)
  say ""
  say "== $name: $(step_field "$e" 4)"
  CHANGED=0
  "step_${name//-/_}"
done

say ""
say "Summary: $N_UNCHANGED unchanged, $N_NEW new, $N_UPDATE to update (with .bak.$TS backups)"
if ((${#DRIFT[@]})); then
  say "Targets that differ from the repo:"
  printf '  %s\n' "${DRIFT[@]}"
fi
if ((${#NOTES[@]})); then
  say "Reminders:"
  printf '  - %s\n' "${NOTES[@]}"
fi
say "Not automated: Omarchy install, the other repositories (lwupdate, omasnap, wine-thumbs, oskar, omabump) and the 'things to check' list in README.md."
((APPLY)) || say "Dry run only. Re-run with --apply to make these changes."
