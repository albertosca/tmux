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

apply_window_formats() {
  local target="$1" current_fmt="$2" inactive_fmt="$3"
  # Aplica no escopo da sessão (janelas novas herdam)
  tmux set-option -wt "${target}:" window-status-current-format "$current_fmt" 2>/dev/null || true
  tmux set-option -wt "${target}:" window-status-format         "$inactive_fmt" 2>/dev/null || true
  # Aplica em todas as janelas existentes (sem isso janelas abertas não atualizam)
  tmux list-windows -t "$target" -F '#{window_index}' 2>/dev/null | while IFS= read -r idx; do
    tmux set-window-option -t "${target}:${idx}" window-status-current-format "$current_fmt"
    tmux set-window-option -t "${target}:${idx}" window-status-format         "$inactive_fmt"
  done
}

reset_window_formats() {
  local target="$1"
  tmux set-option -uwt "${target}:" window-status-current-format 2>/dev/null || true
  tmux set-option -uwt "${target}:" window-status-format         2>/dev/null || true
  tmux list-windows -t "$target" -F '#{window_index}' 2>/dev/null | while IFS= read -r idx; do
    tmux set-window-option -u -t "${target}:${idx}" window-status-current-format 2>/dev/null || true
    tmux set-window-option -u -t "${target}:${idx}" window-status-format         2>/dev/null || true
  done
}

case "$session" in
  work*)
    tmux set-option -t "$session" status-bg colour31
    tmux set-option -t "$session" status-fg colour255
    tmux set-option -t "$session" pane-active-border-style "fg=colour51,bg=colour236"
    apply_window_formats "$session" \
      "#[fg=colour51,bg=colour51]⮀#[fg=colour255,bg=colour51,bold] #I ⮁ #W #[fg=colour51,bg=colour31]⮀" \
      "#[fg=colour255,bg=colour31] #I  #W "
    ;;
  personal*)
    tmux set-option -t "$session" status-bg colour130
    tmux set-option -t "$session" status-fg colour255
    tmux set-option -t "$session" pane-active-border-style "fg=colour172,bg=colour236"
    apply_window_formats "$session" \
      "#[fg=colour130,bg=colour172]⮀#[fg=colour255,bg=colour172,bold] #I ⮁ #W #[fg=colour172,bg=colour130]⮀" \
      "#[fg=colour255,bg=colour130] #I  #W "
    ;;
  *)
    tmux set-option -u -t "$session" status-bg 2>/dev/null || true
    tmux set-option -u -t "$session" status-fg 2>/dev/null || true
    tmux set-option -u -t "$session" pane-active-border-style 2>/dev/null || true
    reset_window_formats "$session"
    ;;
esac
