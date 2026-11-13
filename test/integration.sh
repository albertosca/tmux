#!/usr/bin/env bash
# Integration suite — inicia tmux num socket isolado, carrega o conf real
# e interroga as options/bindings resultantes.
#
# Isolamento: socket name = "claude-test-$$" (PID do processo). Não toca nas
# suas sessões reais.

CONF="$HOME/.config/tmux/tmux.conf"
PLUGINS_DIR="$HOME/.config/tmux/plugins"
SOCKET="claude-test-$$"
TMPERR=$(mktemp -t tmux-test-err.XXXXXX)

# Stdlib de interação com o socket isolado
tx() { tmux -L "$SOCKET" "$@"; }

cleanup_integration() {
  tx kill-server 2>/dev/null || true
  # tmux kill-server NÃO remove o socket file — precisamos remover manualmente
  local tmpdir="${TMUX_TMPDIR:-/tmp/tmux-$(id -u)}"
  rm -f "$tmpdir/$SOCKET"
  rm -f "$TMPERR"
}

test_config_loads() {
  # Sobe sessão detached — isso força o source-file do conf
  if tx -f "$CONF" new-session -d -s tcheck 2>"$TMPERR"; then
    ok "conf carrega sem erro fatal"
    if [[ -s "$TMPERR" && ${VERBOSE:-0} -ge 2 ]]; then
      printf "      %b(stderr não-fatal):%b\n" "$DIM" "$RESET"
      sed 's/^/        /' "$TMPERR"
    fi
    return 0
  else
    fail "conf falhou ao carregar" "$(cat "$TMPERR")"
    return 1
  fi
}

test_tmux_native_arch() {
  local tmux_bin
  tmux_bin=$(command -v tmux)
  if file "$tmux_bin" | grep -q "arm64"; then
    ok "tmux binário tem slice arm64 nativa ($tmux_bin)"
  else
    fail "tmux binário sem slice arm64" "$(file "$tmux_bin")"
  fi
}

# O binário ser arm64 não garante pane nativo: default-command pode envelopar
# o shell num wrapper Intel (reattach-to-user-namespace) e todo o pane herda
# Rosetta. Este teste mede dentro de um pane real, spawnado sem comando
# explícito — o mesmo caminho (default-command) que um pane de verdade usa.
#
# Servidor próprio criado via arch -arm64: o macOS herda a preferência de
# slice x86_64 pela linhagem inteira de processos (mesmo através de um
# binário arm64-only no meio), então um caller da suite rodando sob Rosetta
# contaminaria o resultado. arch -arm64 normaliza só a preferência — um
# wrapper x86_64-only na cadeia ainda força tradução e reprova o teste.
test_pane_native_arch() {
  local out socket translated
  out=$(mktemp -t tmux-test-arch.XXXXXX)
  socket="claude-test-arch-$$"
  if ! arch -arm64 tmux -L "$socket" -f "$CONF" new-session -d -s archcheck 2>/dev/null; then
    fail "pane nativo: servidor de teste não subiu via arch -arm64"
    rm -f "$out"
    return
  fi
  sleep 1
  tmux -L "$socket" send-keys -t archcheck "sysctl -n sysctl.proc_translated > '$out'; echo done >> '$out'" Enter

  # 150 × 0.1s = 15s. O shell do pane carrega o .zshrc inteiro antes de rodar
  # o comando; com a máquina sob carga (suites em paralelo) os 5s originais
  # estouravam e a medição saía vazia.
  local poll_attempt=0
  while [[ $poll_attempt -lt 150 ]] && ! grep -q "done" "$out" 2>/dev/null; do
    sleep 0.1
    poll_attempt=$((poll_attempt + 1))
  done
  local measured=0
  grep -q "done" "$out" 2>/dev/null && measured=1
  translated=$(head -1 "$out" 2>/dev/null)
  tmux -L "$socket" kill-server 2>/dev/null
  rm -f "$out" "${TMUX_TMPDIR:-/tmp/tmux-$(id -u)}/$socket"

  # "não consegui medir" é um resultado terceiro, nunca Rosetta: o timeout
  # devolvia string vazia e o else pintava de vermelho com a mensagem errada,
  # mandando procurar Rosetta onde o defeito era o relógio do teste.
  if [[ "$measured" -eq 0 ]]; then
    fail "pane nativo: medição não completou em 15s" \
      "timeout esperando o comando rodar no pane — resultado indeterminado, NÃO é Rosetta"
  elif [[ "$translated" == "0" ]]; then
    ok "pane roda nativo (proc_translated = 0)"
  else
    fail "pane roda sob Rosetta" "proc_translated = '$translated' (esperado 0)"
  fi
}

# As funções abaixo assumem que test_config_loads já rodou com sucesso
gopt() { tx show-options -gv "$1" 2>/dev/null; }
wopt() { tx show-window-options -gv "$1" 2>/dev/null; }

test_opt_prefix() {
  assert_eq "prefix = C-a" "$(gopt prefix)" "C-a"
}

test_opt_base_index() {
  assert_eq "base-index = 1" "$(gopt base-index)" "1"
}

test_opt_pane_base_index() {
  assert_eq "pane-base-index = 1" "$(wopt pane-base-index)" "1"
}

test_opt_renumber_windows() {
  assert_eq "renumber-windows = on" "$(gopt renumber-windows)" "on"
}

test_opt_history_limit() {
  assert_eq "history-limit = 50000" "$(gopt history-limit)" "50000"
}

test_opt_mouse() {
  assert_eq "mouse = on" "$(gopt mouse)" "on"
}

test_opt_focus_events() {
  assert_eq "focus-events = on" "$(gopt focus-events)" "on"
}

test_opt_aggressive_resize() {
  assert_eq "aggressive-resize = on" "$(gopt aggressive-resize)" "on"
}

test_opt_allow_rename() {
  assert_eq "allow-rename = off" "$(gopt allow-rename)" "off"
}

test_opt_automatic_rename() {
  assert_eq "automatic-rename = on" "$(wopt automatic-rename)" "on"
}

test_opt_default_terminal() {
  assert_eq "default-terminal = tmux-256color" "$(gopt default-terminal)" "tmux-256color"
}

test_opt_mode_keys() {
  assert_eq "mode-keys = vi" "$(wopt mode-keys)" "vi"
}

test_opt_status_keys() {
  assert_eq "status-keys = vi" "$(gopt status-keys)" "vi"
}

test_opt_escape_time_low() {
  # tmux-sensible seta escape-time=0. Se o user mexeu, pelo menos < 50ms.
  local escape_time_milliseconds
  escape_time_milliseconds=$(gopt escape-time)
  if [[ "$escape_time_milliseconds" -lt 50 ]] 2>/dev/null; then
    ok "escape-time baixo (${escape_time_milliseconds}ms)"
  else
    fail "escape-time alto: ${escape_time_milliseconds}ms" "deve ser 0 (tmux-sensible) ou muito baixo"
  fi
}

# ── Plugin vars (via @options) ──────────────────────────────────────────────
test_var_continuum_restore() {
  assert_eq "@continuum-restore = on" "$(gopt @continuum-restore)" "on"
}

test_var_resurrect_strategy() {
  assert_eq "@resurrect-strategy-vim = session" "$(gopt @resurrect-strategy-vim)" "session"
}

test_var_sessionx_bind() {
  assert_eq "@sessionx-bind = O" "$(gopt @sessionx-bind)" "O"
}

test_var_extrakto_key() {
  assert_eq "@extrakto_key = Tab" "$(gopt @extrakto_key)" "Tab"
}

test_var_extrakto_clip() {
  assert_eq "@extrakto_clip_tool = pbcopy" "$(gopt @extrakto_clip_tool)" "pbcopy"
}

# Fora do macOS o pbcopy não existe, então fixar a opção nele faz o extrakto
# falhar ao copiar. Um uname falso na frente do PATH faz o conf achar que está
# no Linux; "auto" deixa o plugin escolher wl-copy ou xclip (lido no código dele).
test_var_extrakto_clip_not_pinned_on_linux() {
  local fake_bin socket value tmpdir
  fake_bin=$(mktemp -d)
  printf '#!/bin/sh\necho Linux\n' > "$fake_bin/uname"
  chmod +x "$fake_bin/uname"
  socket="claude-test-linux-$$"
  if ! PATH="$fake_bin:$PATH" tmux -L "$socket" -f "$CONF" new-session -d -s linuxcheck 2>/dev/null; then
    fail "linux: servidor de teste não subiu com uname falso"
    rm -rf "$fake_bin"
    return
  fi
  value=$(tmux -L "$socket" show-option -gv @extrakto_clip_tool 2>/dev/null)
  tmux -L "$socket" kill-server 2>/dev/null || true
  tmpdir="${TMUX_TMPDIR:-/tmp/tmux-$(id -u)}"
  rm -f "$tmpdir/$socket"
  rm -rf "$fake_bin"
  assert_eq "linux: @extrakto_clip_tool = auto (não fixado em pbcopy)" "$value" "auto"
}

# ── Bindings (list-keys) ────────────────────────────────────────────────────
# Abstração: passa um grep pattern, recebe match/no-match
keys() { tx list-keys -T prefix 2>/dev/null; }

assert_key_bound() {
  local label=$1 pattern=$2
  if keys | grep -qE -- "$pattern"; then
    ok "$label"
  else
    fail "$label" "não encontrado em list-keys: $pattern"
  fi
}

test_bind_swap_window_left_repeatable() {
  assert_key_bound "prefix + < (swap-window left, repeatable)" 'bind-key +-r.*-T prefix +<.*swap-window'
}

test_bind_swap_window_right_repeatable() {
  assert_key_bound "prefix + > (swap-window right, repeatable)" 'bind-key +-r.*-T prefix +>.*swap-window'
}

test_hooks_session_theme() {
  local hooks
  hooks=$(tx show-hooks -g 2>/dev/null)
  if echo "$hooks" | grep -q 'session-theme'; then
    ok "hooks de session-theme registrados"
  else
    fail "hooks de session-theme ausentes" "esperado em show-hooks -g"
  fi
}

# Runs a script as if from inside the isolated server: TMUX points the plain
# `tmux` calls in it at that socket, and stderr comes back (run-shell on a
# server without a client swallows it).
run_on_socket() {
  local socket=$1; shift
  local socket_path
  socket_path=$(tmux -L "$socket" display-message -p '#{socket_path}' 2>/dev/null)
  TMUX="$socket_path,0,0" "$@" 2>&1
}

# gravel value of one option in a generated theme file (dark or light).
theme_value() {
  sed -n "s/^set -g @gravel-$2 \"\\(#[0-9a-f]*\\)\"$/\\1/p" "$(dirname "$CONF")/theme/gravel-$1.conf"
}

test_theme_switch_repaints_bar_and_sessions() {
  # Review 2026-11-13: sourcing gravel-light.conf by hand left the -gF styles
  # and the per-session bars dark. switch.sh must repaint all of them.
  local socket="claude-switch-$$" script light_ground light_faint light_work
  script="$(dirname "$CONF")/theme/switch.sh"
  light_ground=$(theme_value light ground)
  light_faint=$(theme_value light faint)
  light_work=$(theme_value light work-bar)
  if ! tmux -L "$socket" -f "$CONF" new-session -d -s work1 2>/dev/null; then
    fail "switch: server did not start" "$CONF"
    return 1
  fi
  run_on_socket "$socket" bash "$script" light >/dev/null
  assert_eq "switch: mode option is light" "light" "$(tmux -L "$socket" show -gv @gravel-mode 2>/dev/null)"
  assert_match "switch: status bar takes the light ground" "$(tmux -L "$socket" show -gv status-style 2>/dev/null)" "bg=$light_ground"
  assert_match "switch: pane border takes the light faint" "$(tmux -L "$socket" show -gv pane-border-style 2>/dev/null)" "fg=$light_faint"
  assert_eq "switch: clock mode takes the light muted" "$(theme_value light muted)" "$(tmux -L "$socket" show -gwv clock-mode-colour 2>/dev/null)"
  assert_eq "switch: work session bar is repainted" "$light_work" "$(tmux -L "$socket" show -v -t work1 status-bg 2>/dev/null)"
  run_on_socket "$socket" bash "$script" dark >/dev/null
  assert_eq "switch: back to dark" "$(theme_value dark work-bar)" "$(tmux -L "$socket" show -v -t work1 status-bg 2>/dev/null)"
  tmux -L "$socket" kill-server 2>/dev/null || true
}

test_fresh_server_loads_the_dark_theme() {
  # 2026-11-13: `source-file -F '~/...'` failed silently and a fresh server
  # came up with no @gravel-* options and tmux's default bar.
  local socket="claude-fresh-$$"
  tmux -L "$socket" -f "$CONF" new-session -d -s fresh 2>/dev/null
  assert_eq "fresh server: theme loaded" "$(theme_value dark ink)" "$(tmux -L "$socket" show -gv @gravel-ink 2>/dev/null)"
  assert_match "fresh server: status bar on the theme ground" "$(tmux -L "$socket" show -gv status-style 2>/dev/null)" "bg=$(theme_value dark ground)"
  tmux -L "$socket" kill-server 2>/dev/null || true
}

test_session_theme_without_a_sourced_theme() {
  # Review 2026-11-13: on a server that never sourced the theme, session-theme
  # printed "bad colour" and painted nothing. It now loads the theme itself.
  local socket="claude-bare-$$" script
  script="$(dirname "$CONF")/scripts/session-theme.sh"
  tmux -L "$socket" -f /dev/null new-session -d -s work1 2>/dev/null
  local output
  output=$(run_on_socket "$socket" bash "$script" work1)
  assert_not_match "bare server: no bad colour" "$output" "bad colour"
  assert_not_match "bare server: no invalid style" "$output" "invalid style"
  assert_eq "bare server: work bar painted from the theme file" "$(theme_value dark work-bar)" "$(tmux -L "$socket" show -v -t work1 status-bg 2>/dev/null)"
  tmux -L "$socket" kill-server 2>/dev/null || true
}

test_bind_split_pipe() {
  assert_key_bound "prefix + \\ (split horizontal)" 'bind-key.*-T prefix +\\\\.*split-window -h'
}

test_bind_split_dash() {
  assert_key_bound "prefix + - (split vertical)" 'bind-key.*-T prefix +-.*split-window -v'
}

test_bind_reload() {
  assert_key_bound "prefix + r (reload)" 'bind-key.*-T prefix +r.*source-file'
}

test_bind_claude_popup() {
  assert_key_bound "prefix + C (Claude popup)" 'bind-key.*-T prefix +C.*display-popup.*claude'
}

test_bind_lazygit_popup() {
  assert_key_bound "prefix + G (lazygit popup)" 'bind-key.*-T prefix +G.*display-popup.*lazygit'
}

test_bind_scratch_popup() {
  assert_key_bound "prefix + T (scratch popup)" 'bind-key.*-T prefix +T.*display-popup'
}

test_bind_clear_fallback() {
  assert_key_bound "prefix + C-l (clear fallback)" "bind-key.*-T prefix +C-l.*send-keys"
}

test_bind_window_0_to_10() {
  # base-index=1 → tecla 0 fica sem função; mapeamos pra janela 10
  assert_key_bound "prefix + 0 → select-window :10" 'bind-key.*-T prefix +0.*select-window.*:10'
}

test_bind_rename_session_e() {
  # rename-session sem Shift: prefix+e (alternativa ao prefix+$)
  assert_key_bound "prefix + e → rename-session (sem Shift)" 'bind-key.*-T prefix +e.*rename-session'
}

test_bind_pending_mark() {
  # prefix+m → marca manual de pendência; o comando é guarded (test -f)
  # então o binding existe mesmo em máquina sem o hook do Claude
  assert_key_bound "prefix + m → pending mark (guarded)" 'bind-key.*-T prefix +m .*run-shell.*tmux-pending'
}

# ── Copy-mode bindings ──────────────────────────────────────────────────────
test_copy_mode_v() {
  if tx list-keys -T copy-mode-vi 2>/dev/null | grep -qE 'bind-key +-T copy-mode-vi +v +send-keys -X begin-selection'; then
    ok "copy-mode-vi: v → begin-selection"
  else
    fail "copy-mode-vi: v binding ausente"
  fi
}

test_copy_mode_y_pbcopy() {
  if tx list-keys -T copy-mode-vi 2>/dev/null | grep -qE 'bind-key +-T copy-mode-vi +y +send-keys -X copy-pipe-and-cancel'; then
    ok "copy-mode-vi: y → copy-pipe-and-cancel"
  else
    fail "copy-mode-vi: y binding ausente"
  fi
}

test_copy_mode_rectangle() {
  if tx list-keys -T copy-mode-vi 2>/dev/null | grep -qE 'bind-key +-T copy-mode-vi +C-v +send-keys -X rectangle-toggle'; then
    ok "copy-mode-vi: C-v → rectangle-toggle"
  else
    fail "copy-mode-vi: C-v binding ausente"
  fi
}

# ── Runtime visual/bell/monitor options ──────────────────────────────────────
test_opt_visual_activity() {
  assert_eq "visual-activity = off" "$(gopt visual-activity)" "off"
}

test_opt_visual_bell() {
  assert_eq "visual-bell = off" "$(gopt visual-bell)" "off"
}

test_opt_visual_silence() {
  assert_eq "visual-silence = off" "$(gopt visual-silence)" "off"
}

test_opt_monitor_activity() {
  assert_eq "monitor-activity = off" "$(wopt monitor-activity)" "off"
}

test_opt_bell_action() {
  assert_eq "bell-action = none" "$(gopt bell-action)" "none"
}

test_opt_set_titles() {
  assert_eq "set-titles = on" "$(gopt set-titles)" "on"
}

# ── Runtime status bar options ───────────────────────────────────────────────
test_opt_status_justify() {
  assert_eq "status-justify = left" "$(gopt status-justify)" "left"
}

test_opt_status_position() {
  assert_eq "status-position = bottom" "$(gopt status-position)" "bottom"
}

test_opt_status_interval() {
  assert_eq "status-interval = 2" "$(gopt status-interval)" "2"
}

test_opt_status_left_length() {
  # Era 20; subiu pra 60 pra caber a lista de sessões na status-left
  assert_eq "status-left-length = 60" "$(gopt status-left-length)" "60"
}

# ── Remaining plugin vars ────────────────────────────────────────────────────
test_var_shell_mode() {
  assert_eq "@shell_mode = vi" "$(gopt @shell_mode)" "vi"
}

test_var_open() {
  assert_eq "@open = C-o" "$(gopt @open)" "C-o"
}

test_var_open_editor() {
  assert_eq "@open-editor = o" "$(gopt @open-editor)" "o"
}

test_var_sessionx_window_mode() {
  assert_eq "@sessionx-window-mode = on" "$(gopt @sessionx-window-mode)" "on"
}

test_var_sessionx_preview() {
  assert_eq "@sessionx-preview-enabled = true" "$(gopt @sessionx-preview-enabled)" "true"
}

test_var_extrakto_default_opt() {
  assert_eq "@extrakto_default_opt = word" "$(gopt @extrakto_default_opt)" "word"
}

# ── Remaining key bindings (prefix table) ────────────────────────────────────
test_bind_send_prefix() {
  assert_key_bound "prefix + C-a (send-prefix)" 'bind-key.*-T prefix +C-a.*send-prefix'
}

test_bind_new_window() {
  assert_key_bound "prefix + c (new-window -c cwd)" 'bind-key.*-T prefix +c.*new-window.*-c "#\{pane_current_path\}"'
}

test_bind_pane_select_h() {
  assert_key_bound "prefix + h (pane left)" 'bind-key.*-T prefix +h.*select-pane -L'
}

test_bind_pane_select_j() {
  assert_key_bound "prefix + j (pane down)" 'bind-key.*-T prefix +j.*select-pane -D'
}

test_bind_pane_select_k() {
  assert_key_bound "prefix + k (pane up)" 'bind-key.*-T prefix +k.*select-pane -U'
}

test_bind_pane_select_l() {
  assert_key_bound "prefix + l (pane right)" 'bind-key.*-T prefix +l.*select-pane -R'
}

# Resize bindings DEVEM ter flag -r (repeatable) — crítico pro workflow
test_bind_resize_H_repeatable() {
  assert_key_bound "prefix + H (resize -L, repeatable)" 'bind-key +-r.*-T prefix +H.*resize-pane -L'
}

test_bind_resize_J_repeatable() {
  assert_key_bound "prefix + J (resize -D, repeatable)" 'bind-key +-r.*-T prefix +J.*resize-pane -D'
}

test_bind_resize_K_repeatable() {
  assert_key_bound "prefix + K (resize -U, repeatable)" 'bind-key +-r.*-T prefix +K.*resize-pane -U'
}

test_bind_resize_L_repeatable() {
  assert_key_bound "prefix + L (resize -R, repeatable)" 'bind-key +-r.*-T prefix +L.*resize-pane -R'
}

# ── Root-table bindings (prefix-less) ────────────────────────────────────────
rootkeys() { tx list-keys -T root 2>/dev/null; }

assert_root_key_bound() {
  local label=$1 pattern=$2
  if rootkeys | grep -qE -- "$pattern"; then
    ok "$label"
  else
    fail "$label" "não encontrado em list-keys -T root: $pattern"
  fi
}

test_bind_alt_left() {
  assert_root_key_bound "M-Left (pane left)" 'bind-key.*-T root +M-Left.*select-pane -L'
}

test_bind_alt_right() {
  assert_root_key_bound "M-Right (pane right)" 'bind-key.*-T root +M-Right.*select-pane -R'
}

test_bind_alt_up() {
  assert_root_key_bound "M-Up (pane up)" 'bind-key.*-T root +M-Up.*select-pane -U'
}

test_bind_alt_down() {
  assert_root_key_bound "M-Down (pane down)" 'bind-key.*-T root +M-Down.*select-pane -D'
}

test_bind_shift_left() {
  assert_root_key_bound "S-Left (previous-window)" 'bind-key.*-T root +S-Left.*previous-window'
}

test_bind_shift_right() {
  assert_root_key_bound "S-Right (next-window)" 'bind-key.*-T root +S-Right.*next-window'
}

# ── Plugin-provided bindings (skip se plugin não instalado) ──────────────────
test_bind_sessionx_plugin() {
  if [[ ! -d "$PLUGINS_DIR/tmux-sessionx" ]]; then
    skip "tmux-sessionx não instalado"
    return
  fi
  if keys | grep -qE 'bind-key.*-T prefix +O.*run-shell.*sessionx'; then
    ok "prefix + O (sessionx via plugin)"
  else
    # Plugin pode usar outro mecanismo — mais permissivo
    if keys | grep -qE 'bind-key.*-T prefix +O '; then
      ok "prefix + O (sessionx bound)"
    else
      fail "prefix + O sessionx não bound"
    fi
  fi
}

test_bind_extrakto_plugin() {
  if [[ ! -d "$PLUGINS_DIR/extrakto" ]]; then
    skip "extrakto não instalado"
    return
  fi
  if keys | grep -qE 'bind-key.*-T prefix +Tab ' ; then
    ok "prefix + Tab (extrakto bound)"
  else
    fail "prefix + Tab extrakto não bound"
  fi
}

test_bind_vim_tmux_navigator() {
  if [[ ! -d "$PLUGINS_DIR/vim-tmux-navigator" ]]; then
    skip "vim-tmux-navigator não instalado"
    return
  fi
  # vim-tmux-navigator registra C-h/j/k/l na root table
  local missing=()
  for key in C-h C-j C-k C-l; do
    if ! rootkeys | grep -qE "bind-key.*-T root +$key "; then
      missing+=("$key")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "vim-tmux-navigator: C-h/j/k/l todos bound na root"
  else
    fail "vim-tmux-navigator incompleto" "falta: ${missing[*]}"
  fi
}

test_bind_resurrect() {
  if [[ ! -d "$PLUGINS_DIR/tmux-resurrect" ]]; then
    skip "tmux-resurrect não instalado"
    return
  fi
  if keys | grep -qE 'bind-key.*-T prefix +C-s '; then
    ok "prefix + C-s (resurrect save)"
  else
    fail "prefix + C-s não bound"
  fi
  if keys | grep -qE 'bind-key.*-T prefix +C-r '; then
    ok "prefix + C-r (resurrect restore)"
  else
    fail "prefix + C-r não bound"
  fi
}

# ── Entry point ─────────────────────────────────────────────────────────────
suite_integration() {
  reset_suite_counters

  # Skip tudo se TPM ausente — conf ainda carrega, mas bindings de plugins não
  if [[ ! -d "$PLUGINS_DIR/tpm" ]]; then
    skip "TPM não instalado — rode 'prefix + I' primeiro"
    return 0
  fi

  # Dispara o teste; se o conf falhar, aborta o resto
  if ! test_config_loads; then
    cleanup_integration
    return 1
  fi

  test_tmux_native_arch
  test_pane_native_arch

  # Options globais
  test_opt_prefix
  test_opt_base_index
  test_opt_pane_base_index
  test_opt_renumber_windows
  test_opt_history_limit
  test_opt_mouse
  test_opt_focus_events
  test_opt_aggressive_resize
  test_opt_allow_rename
  test_opt_automatic_rename
  test_opt_default_terminal
  test_opt_mode_keys
  test_opt_status_keys
  test_opt_escape_time_low

  # Plugin vars
  test_var_continuum_restore
  test_var_resurrect_strategy
  test_var_sessionx_bind
  test_var_extrakto_key
  test_var_extrakto_clip
  test_var_extrakto_clip_not_pinned_on_linux

  # Hooks
  test_hooks_session_theme
  test_fresh_server_loads_the_dark_theme
  test_theme_switch_repaints_bar_and_sessions
  test_session_theme_without_a_sourced_theme

  # Bindings custom
  test_bind_swap_window_left_repeatable
  test_bind_swap_window_right_repeatable
  test_bind_split_pipe
  test_bind_split_dash
  test_bind_reload
  test_bind_claude_popup
  test_bind_lazygit_popup
  test_bind_scratch_popup
  test_bind_clear_fallback
  test_bind_window_0_to_10
  test_bind_rename_session_e
  test_bind_pending_mark
  test_copy_mode_v
  test_copy_mode_y_pbcopy
  test_copy_mode_rectangle

  # Runtime visual/bell/monitor
  test_opt_visual_activity
  test_opt_visual_bell
  test_opt_visual_silence
  test_opt_monitor_activity
  test_opt_bell_action
  test_opt_set_titles

  # Runtime status bar
  test_opt_status_justify
  test_opt_status_position
  test_opt_status_interval
  test_opt_status_left_length

  # Plugin vars (remaining)
  test_var_shell_mode
  test_var_open
  test_var_open_editor
  test_var_sessionx_window_mode
  test_var_sessionx_preview
  test_var_extrakto_default_opt

  # Remaining prefix bindings
  test_bind_send_prefix
  test_bind_new_window
  test_bind_pane_select_h
  test_bind_pane_select_j
  test_bind_pane_select_k
  test_bind_pane_select_l
  test_bind_resize_H_repeatable
  test_bind_resize_J_repeatable
  test_bind_resize_K_repeatable
  test_bind_resize_L_repeatable

  # Root-table bindings
  test_bind_alt_left
  test_bind_alt_right
  test_bind_alt_up
  test_bind_alt_down
  test_bind_shift_left
  test_bind_shift_right

  # Plugin-provided bindings (skip-aware)
  test_bind_sessionx_plugin
  test_bind_extrakto_plugin
  test_bind_vim_tmux_navigator
  test_bind_resurrect

  cleanup_integration
}
