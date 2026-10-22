#!/bin/bash

# One-time setup of the local-patched pacman repository, then publish the
# current patched builds. Run from a normal terminal (sudo prompts once);
# afterwards run `omarchy update` to install them and log out and back in.

set -euo pipefail

G=$(dirname "$(readlink -f "$0")")
HOOKS=~/.config/omarchy/hooks

if grep -q NoNewPrivs:.1 /proc/self/status; then
  echo "This shell has the no-new-privileges flag (e.g. a Claude Desktop terminal); sudo cannot work here. Use a normal terminal." >&2
  exit 1
fi

# 1. Repo and database first: a Server without its database fails every -Sy.
bash "$G/publish-local-pkg.sh" \
  ~/Work/tmp/hyprland-4.3/hyprland-0.56.2-4.3-x86_64.pkg.tar.zst \
  ~/Work/tmp/hyprland-4.3/hyprpm-0.56.2-4.3-x86_64.pkg.tar.zst \
  ~/Work/omarchy-fixes/remmina/remmina-1:1.4.43-4.1-x86_64.pkg.tar.zst

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
