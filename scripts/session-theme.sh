#!/usr/bin/env bash
# Applies status bar and border colors from the session name.
# Called by the session-created, client-session-changed, session-renamed and
# after-split-window hooks, and by theme/switch.sh.
#
# Convention (colors of the generated gravel theme, @gravel-* options that
# tmux.conf loads from ~/.config/tmux/theme/gravel-<mode>.conf):
#   work*     -> @gravel-work-bar     (work, cool tone)
#   personal* -> @gravel-personal-bar (personal, warm tone)
#   *         -> default (theme ground, overrides removed)
#
# This script only touches SESSION options (status-bg/fg, pane border).
# The window-status formats left it on 25/08/2026 and became dynamic globals
# in tmux.conf that resolve the color from the session name at render time.
# The old version set formats window by window, and that collided with
# Claude's pending indicator (~/.claude/hooks/tmux-pending.sh): the
# indicator's `setw -u` cleanup dropped the window to the grey global format,
# the "grey windows" Alberto reported. Two owners writing to the same scope
# cannot undo each other without trampling; now each has its own (theme =
# dynamic global + session options; indicator = per-window overrides, which
# win over the global while they exist and hand it back on unset).

session="${1:-}"
if [[ -z "$session" ]]; then
  session=$(tmux display-message -p '#S' 2>/dev/null) || exit 0
fi

# A server that never sourced the theme (started with another config, or a
# failed source-file) has no @gravel-* options and every -F below would
# expand to an empty color. Load the theme for the current mode first.
if [[ -z "$(tmux show-options -gv @gravel-ink 2>/dev/null)" ]]; then
  mode=$(tmux show-options -gv @gravel-mode 2>/dev/null)
  theme_directory="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../theme"
  tmux source-file "$theme_directory/gravel-${mode:-dark}.conf"
fi

case "$session" in
  work*)
    tmux set-option -F -t "$session" status-bg "#{@gravel-work-bar}"
    tmux set-option -F -t "$session" status-fg "#{@gravel-ink}"
    tmux set-option -F -t "$session" pane-active-border-style "fg=#{@gravel-muted}"
    ;;
  personal*)
    tmux set-option -F -t "$session" status-bg "#{@gravel-personal-bar}"
    tmux set-option -F -t "$session" status-fg "#{@gravel-ink}"
    tmux set-option -F -t "$session" pane-active-border-style "fg=#{@gravel-muted}"
    ;;
  *)
    tmux set-option -u -t "$session" status-bg 2>/dev/null || true
    tmux set-option -u -t "$session" status-fg 2>/dev/null || true
    tmux set-option -u -t "$session" pane-active-border-style 2>/dev/null || true
    ;;
esac
