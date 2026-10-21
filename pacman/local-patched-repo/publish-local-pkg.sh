#!/bin/bash

# Publish locally built packages to the local-patched pacman repository.
#
#   publish-local-pkg.sh ~/Work/tmp/hyprland-4.2/{hyprland,hyprpm}-*.pkg.tar.zst
#   omarchy update
#
# Publish split packages together (hyprland with hyprpm). The next
# `omarchy update` installs them: [local-patched] is the first repository, so
# its build wins whenever it is newer than the installed one.

set -euo pipefail

REPO_DIR=${LOCAL_REPO_DIR:-/var/lib/local-patched-repo}
REPO_DB=$REPO_DIR/local-patched.db.tar.zst

# A name published here hides Arch's and Omarchy's builds of it until you
# remove it (repo-remove), so the list is explicit.
ALLOWED=(hyprland hyprpm remmina)

if (($# == 0)); then
  echo "Usage: ${0##*/} <package.pkg.tar.zst>..." >&2
  exit 2
fi

pkginfo() { bsdtar -xOf "$1" .PKGINFO | sed -n "s/^$2 = //p"; }

published_version() {
  [[ -r $REPO_DB ]] || return 0
  bsdtar -xOf "$REPO_DB" 2>/dev/null |
    awk -v name="$1" '/^%NAME%$/ { getline; n = $0 } /^%VERSION%$/ { getline; if (n == name) print }'
}

# Check every file before touching the repository.
for pkg in "$@"; do
  if [[ ! -f $pkg || $pkg != *.pkg.tar.zst ]]; then
    echo "Not a package file: $pkg" >&2
    exit 1
  fi
  name=$(pkginfo "$pkg" pkgname)
  version=$(pkginfo "$pkg" pkgver)
  if [[ " ${ALLOWED[*]} " != *" $name "* ]]; then
    echo "$name is not in ALLOWED (${ALLOWED[*]}); not publishing $pkg." >&2
    exit 1
  fi
  current=$(published_version "$name")
  if [[ -n $current ]] && (($(vercmp "$version" "$current") < 0)); then
    echo "$name $version is older than the published $current; not publishing." >&2
    exit 1
  fi
done

# Root-owned and world-readable: pacman downloads as the alpm user, and only
# root may add what the next system upgrade installs.
sudo install -d -o root -g root -m 0755 "$REPO_DIR"
sudo install -o root -g root -m 0644 -t "$REPO_DIR" -- "$@"

published=()
for pkg in "$@"; do
  published+=("$REPO_DIR/${pkg##*/}")
done

# --remove deletes the file of the version each package replaces; the pacman
# cache keeps the last two installed builds.
sudo repo-add --remove "$REPO_DB" "${published[@]}"

echo "Published to $REPO_DIR. Run 'omarchy update' to install."
