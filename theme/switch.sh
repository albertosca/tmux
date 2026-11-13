#!/usr/bin/env bash
# Switches the running tmux server between gravel dark and light:
#   bash ~/.config/tmux/theme/switch.sh light|dark
# Sets @gravel-mode (tmux.conf keeps it on re-source), loads the colors and
# the load-time styles, and repaints every session's bar. Claude's pending
# tabs carry their colors in the hook's FORMAT_VERSION, so they repaint on
# the hook's next event; calling the hook from here would also sweep marks
# of other servers when run against a test socket.
set -euo pipefail

mode="${1:-}"
if [[ "$mode" != "dark" && "$mode" != "light" ]]; then
  echo "usage: $0 dark|light" >&2
  exit 1
fi
theme_directory=$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)
tmux set-option -g @gravel-mode "$mode"
tmux source-file "$theme_directory/gravel-$mode.conf"
tmux source-file "$theme_directory/apply.conf"
while IFS= read -r session; do
  bash "$theme_directory/../scripts/session-theme.sh" "$session"
done < <(tmux list-sessions -F '#{session_name}')
