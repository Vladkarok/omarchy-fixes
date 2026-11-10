#!/bin/bash

# One-time setup of the local-patched pacman repository, then publish the
# patched builds. Run from a normal terminal (sudo prompts once); afterwards
# run `omarchy update` to install them and log out and back in.
#
#   install.sh              # newest packages built in ../../hyprland and ../../remmina
#   install.sh <dir|pkg>... # packages from these directories or files instead
#
# Build the packages first with `makepkg -s` in hyprland/ and remmina/.

set -euo pipefail

G=$(dirname "$(readlink -f "$0")")
REPO_ROOT=$(readlink -f "$G/../..")
HOOKS=~/.config/omarchy/hooks

if grep -q NoNewPrivs:.1 /proc/self/status; then
  echo "This shell has the no-new-privileges flag (e.g. a Claude Desktop terminal); sudo cannot work here. Use a normal terminal." >&2
  exit 1
fi

# Newest <name>-<version>-<arch>.pkg.tar.zst among the given directories and
# files, compared with vercmp. Debug packages are skipped.
newest() {
  local name=$1 best="" best_ver="" f base ver
  shift
  for f in "$@"; do
    base=${f##*/}
    [[ $base == "$name"-*.pkg.tar.zst ]] || continue
    ver=${base#"$name"-}
    ver=${ver%-*.pkg.tar.zst}
    # Skip other packages that share the prefix (hyprland-debug-...).
    [[ $ver =~ ^[0-9] ]] || continue
    if [[ -z $best ]] || (($(vercmp "$ver" "$best_ver") > 0)); then
      best=$f best_ver=$ver
    fi
  done
  [[ -n $best ]] && printf '%s\n' "$best"
}

sources=("$@")
((${#sources[@]})) || sources=("$REPO_ROOT/hyprland" "$REPO_ROOT/remmina")

candidates=()
for s in "${sources[@]}"; do
  if [[ -d $s ]]; then
    shopt -s nullglob
    candidates+=("$s"/*.pkg.tar.zst)
    shopt -u nullglob
  elif [[ -f $s ]]; then
    candidates+=("$s")
  else
    echo "No such file or directory: $s" >&2
    exit 1
  fi
done

pkgs=()
missing=()
for name in hyprland hyprpm remmina; do
  if p=$(newest "$name" "${candidates[@]}"); then
    pkgs+=("$p")
  else
    missing+=("$name")
  fi
done

if ((${#missing[@]})); then
  echo "No built package found for: ${missing[*]}" >&2
  echo "Looked in: ${sources[*]}" >&2
  echo "Build them with 'makepkg -s' in $REPO_ROOT/hyprland and $REPO_ROOT/remmina, or pass the package paths." >&2
  exit 1
fi

echo "Publishing:"
printf '  %s\n' "${pkgs[@]}"

# 1. Repo and database first: a Server without its database fails every -Sy.
bash "$G/publish-local-pkg.sh" "${pkgs[@]}"

# 2. The snippet before the Include line: an Include of a missing file is fatal.
sudo install -o root -g root -m 0644 "$G/custom-repos.conf" /etc/pacman.d/custom-repos.conf

# 3. Hooks: re-add the repo after every channel switch, warn after updates.
install -D -m 0755 "$G/10-local-patched-repo" "$HOOKS/pre-refresh-pacman.d/10-local-patched-repo"
install -D -m 0755 "$G/20-warn-shadowed-local-pkgs" "$HOOKS/post-update.d/20-warn-shadowed-local-pkgs"

# 4. Add the Include to the current pacman.conf; the hook checks the order.
"$HOOKS/pre-refresh-pacman.d/10-local-patched-repo"

sudo -u alpm test -r /var/lib/local-patched-repo/local-patched.db && echo "alpm can read the repo"
echo "Repositories in order:"
pacman-conf --repo-list
echo "Now run: omarchy update"
