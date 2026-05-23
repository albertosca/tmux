#!/usr/bin/env bash
# Aplica cores de status bar e borda baseadas no nome da sessão.
# Invocado pelos hooks session-created, client-session-changed e session-renamed.
#
# Convenção:
#   work*     → ciano  (trabalho)
#   personal* → laranja (pessoal)
#   *         → padrão (preto, remove overrides)

session="${1:-}"
if [[ -z "$session" ]]; then
  session=$(tmux display-message -p '#S' 2>/dev/null) || exit 0
fi

case "$session" in
  work*)
    tmux set-option -t "$session" status-bg colour31
    tmux set-option -t "$session" status-fg colour255
    tmux set-option -t "$session" pane-active-border-style "fg=colour51,bg=colour236"
    ;;
  personal*)
    tmux set-option -t "$session" status-bg colour208
    tmux set-option -t "$session" status-fg colour235
    tmux set-option -t "$session" pane-active-border-style "fg=colour214,bg=colour235"
    ;;
  *)
    tmux set-option -u -t "$session" status-bg 2>/dev/null || true
    tmux set-option -u -t "$session" status-fg 2>/dev/null || true
    tmux set-option -u -t "$session" pane-active-border-style 2>/dev/null || true
    ;;
esac
