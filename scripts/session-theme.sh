#!/usr/bin/env bash
# Aplica cores de status bar e borda baseadas no nome da sessão.
# Invocado pelos hooks session-created, client-session-changed,
# session-renamed e after-split-window.
#
# Convenção:
#   work*     → ciano  (trabalho)
#   personal* → laranja (pessoal)
#   *         → padrão (preto, remove overrides)
#
# Este script só mexe em OPÇÕES DE SESSÃO (status-bg/fg, borda de pane).
# Os window-status-formats saíram daqui em 25/08/2026: viraram globais
# dinâmicos no tmux.conf, que resolvem a cor pelo nome da sessão no render.
# A versão antiga aplicava formato window a window (única forma de "escopo
# de sessão" que opção de window aceita), e isso colidia com o indicador de
# pendência do Claude (~/.claude/hooks/tmux-pending.sh): o `setw -u` da
# limpeza do indicador derrubava a window no formato global cinza — as
# "windows cinzas" que o Alberto reportou. Dois donos escrevendo no mesmo
# escopo não têm como se desfazer sem se atropelar; agora cada um tem o seu
# (tema = global dinâmico + opções de sessão; indicador = overrides por
# window, que vencem o global enquanto existem e o devolvem no unset).

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
    tmux set-option -t "$session" status-bg colour130
    tmux set-option -t "$session" status-fg colour255
    tmux set-option -t "$session" pane-active-border-style "fg=colour172,bg=colour236"
    ;;
  *)
    tmux set-option -u -t "$session" status-bg 2>/dev/null || true
    tmux set-option -u -t "$session" status-fg 2>/dev/null || true
    tmux set-option -u -t "$session" pane-active-border-style 2>/dev/null || true
    ;;
esac
