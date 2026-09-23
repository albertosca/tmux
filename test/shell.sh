#!/usr/bin/env bash
# Shell suite — checagens estáticas no tmux.conf.
# Não inicia tmux; só analisa o conteúdo do arquivo + presença de arquivos.

CONF="$HOME/.config/tmux/tmux.conf"
PLUGINS_DIR="$HOME/.config/tmux/plugins"

# ── File integrity ───────────────────────────────────────────────────────────
test_conf_exists() {
  if [[ -f "$CONF" ]]; then
    ok "tmux.conf existe"
  else
    fail "tmux.conf não encontrado" "$CONF"
  fi
}

test_readme_exists() {
  [[ -f "$HOME/.config/tmux/README.md" ]] \
    && ok "README.md existe" \
    || fail "README.md não encontrado"
}

test_cheatsheet_exists() {
  [[ -f "$HOME/.config/tmux/CHEATSHEET.md" ]] \
    && ok "CHEATSHEET.md existe" \
    || fail "CHEATSHEET.md não encontrado"
}

# ── Regressões (bugs já corrigidos, não podem voltar) ────────────────────────
test_no_bgbright_typo() {
  assert_not_grep "sem typo 'bgbright='" 'bgbright=' "$CONF"
}

test_no_empty_bg_attr() {
  # #[bg=] (sem valor) é sintaxe inválida; a gente corrigiu pra #[bg=default]
  assert_not_grep "sem atributo #[bg=] vazio" '#\[bg=\]' "$CONF"
}

test_no_screen_256color() {
  # Migramos pra tmux-256color; screen-256color não deve voltar
  assert_not_grep "sem 'screen-256color'" '^[^#]*screen-256color' "$CONF"
}

test_no_monitor_activity_on() {
  # Linha 'monitor-activity on' era contraditória com 'off' mais abaixo
  assert_not_grep "sem 'monitor-activity on'" '^[^#]*set.*monitor-activity on' "$CONF"
}

test_status_left_shows_sessions() {
  # status-left exibe sessões via `tmux ls` (não é mais string vazia)
  assert_grep "status-left exibe sessões (tmux ls)" 'status-left.*tmux ls' "$CONF"
  # Formato usa ##S escapado — sem isso o nome duplica (bug de expansão dentro de #(...))
  assert_grep "status-left escapa ##S corretamente" 'status-left.*##S' "$CONF"
  # Sessão ativa em negrito
  assert_grep "status-left: sessão ativa em bold" 'status-left.*bold' "$CONF"
}

test_status_left_no_strftime_percent_s() {
  # REGRESSÃO: tmux interpreta %s como strftime (Unix timestamp) dentro de #(...).
  # O awk usa %%s pra que o tmux converta para %s literal antes de passar ao shell.
  # Um %s nu apareceria como número incrementando na barra (ex: 1778717521).
  local line
  line=$(grep "^set -g status-left " "$CONF")
  # Não deve haver %s não-escapado (%%s é ok, %s nu não é)
  if echo "$line" | grep -qE '[^%]%s|^%s'; then
    fail "status-left contém %s nu (seria substituído por timestamp Unix)" \
         "use %%s para escapar — tmux converte %%→% antes de passar ao shell"
  else
    ok "status-left não tem %s nu (usa %%s para awk printf)"
  fi
}

test_status_left_no_comma_in_bold_attr() {
  # REGRESSÃO: #[fg=colour255,bold] dentro de #{?cond,true,false} quebra o parser
  # de ternário — a vírgula em ,bold] é interpretada como separador de branches,
  # truncando o branch true em #[fg=colour255 e jogando bold] no false.
  # Fix correto: #[fg=colour255]#[bold] (dois blocos separados, sem vírgula).
  local line
  line=$(grep "^set -g status-left " "$CONF")
  if echo "$line" | grep -qE '#\[fg=colour[0-9]+,bold\]'; then
    fail "status-left usa #[fg=X,bold] dentro de ternário #{?}" \
         "use #[fg=X]#[bold] para evitar que a vírgula quebre o parser de #{?cond,true,false}"
  else
    ok "status-left sem #[fg=X,bold] em ternário (usa #[fg=X]#[bold] corretamente)"
  fi
}

test_window_0_mapped_to_10() {
  assert_grep "prefix+0 → janela 10 (base-index=1)" 'bind-key 0 select-window -t :10' "$CONF"
}

test_rename_session_no_shift() {
  assert_grep "prefix+e → rename-session (sem shift)" 'bind-key e command-prompt.*rename-session' "$CONF"
}

test_no_vs_splits() {
  # Splits migraram pra |/-; v/s foram removidos
  assert_not_grep "sem split 'v'" "^bind-key v split-window" "$CONF"
  assert_not_grep "sem split 's'" "^bind-key s split-window" "$CONF"
}

# ── Opções críticas presentes ────────────────────────────────────────────────
test_prefix_binding() {
  assert_grep "prefix C-a" '^set-option -g prefix C-a' "$CONF"
}

test_base_index() {
  assert_grep "base-index 1" 'set -g base-index 1' "$CONF"
  assert_grep "pane-base-index 1" 'setw -g pane-base-index 1' "$CONF"
  assert_grep "renumber-windows on" 'set -g renumber-windows on' "$CONF"
}

test_vi_modes() {
  assert_grep "mode-keys vi" 'setw -g mode-keys vi' "$CONF"
  assert_grep "status-keys vi" 'set -g status-keys vi' "$CONF"
}

test_mouse_and_focus() {
  assert_grep "mouse on" 'set -g mouse on' "$CONF"
  assert_grep "focus-events on" 'set -g focus-events on' "$CONF"
  assert_grep "aggressive-resize on" 'set -g aggressive-resize on' "$CONF"
  assert_grep "allow-rename off" 'set-option -g allow-rename off' "$CONF"
}

test_history_limit() {
  assert_grep "history-limit 50000" 'set -g history-limit 50000' "$CONF"
}

# ── True color + undercurl ───────────────────────────────────────────────────
test_true_color() {
  assert_grep "default-terminal tmux-256color" 'default-terminal "tmux-256color"' "$CONF"
  assert_grep "RGB capability override" 'terminal-overrides.*xterm-256color:RGB' "$CONF"
}

test_undercurl() {
  assert_grep "Smulx (undercurl shape)" 'Smulx' "$CONF"
  assert_grep "Setulc (undercurl color)" 'Setulc' "$CONF"
}

# ── Bindings custom ──────────────────────────────────────────────────────────
test_modern_splits() {
  assert_grep "split \\ (horizontal)" "bind-key '\\\\' split-window -h" "$CONF"
  assert_grep "split - (vertical)" 'bind-key - split-window -v' "$CONF"
}

test_swap_window_bindings() {
  assert_grep "swap-window < (mover janela esq)" 'bind-key.*< swap-window -t -1' "$CONF"
  assert_grep "swap-window > (mover janela dir)" 'bind-key.*> swap-window -t \+1' "$CONF"
}

test_session_theme_hooks() {
  assert_grep "hook session-created → session-theme" 'set-hook.*session-created.*session-theme' "$CONF"
  assert_grep "hook client-session-changed → session-theme" 'set-hook.*client-session-changed.*session-theme' "$CONF"
  assert_grep "hook session-renamed → session-theme" 'set-hook.*session-renamed.*session-theme' "$CONF"
  # after-new-window saiu em 26/08/2026 e a ausência dele é a asserção agora:
  # os window-status-formats viraram globais DINÂMICOS (resolvem a cor por #S
  # no render), então janela nova já nasce com o tema certo sem ninguém
  # reaplicar. Um hook reaplicando formato por-window é justamente o que
  # colidia com o indicador de pendência, que também escreve nesse escopo.
  assert_not_grep "sem hook after-new-window (formato global dinâmico dispensa reaplicar)" 'set-hook.*after-new-window.*session-theme' "$CONF"
  assert_grep "hook after-split-window → session-theme (evita flash de cor global ao criar pane)" 'set-hook.*after-split-window.*session-theme' "$CONF"
}

test_session_theme_script_exists() {
  local script="$HOME/.config/tmux/scripts/session-theme.sh"
  if [[ -f "$script" && -x "$script" ]]; then
    ok "session-theme.sh existe e é executável"
  elif [[ -f "$script" ]]; then
    fail "session-theme.sh existe mas NÃO é executável" "$script"
  else
    fail "session-theme.sh não encontrado" "$script"
  fi
}

test_popup_bindings() {
  assert_grep "popup Claude (prefix+C)" 'bind-key C display-popup.*claude' "$CONF"
  assert_grep "popup lazygit (prefix+G)" 'bind-key G display-popup.*lazygit' "$CONF"
  assert_grep "popup scratch (prefix+T)" 'bind-key T display-popup' "$CONF"
}

test_reload_binding() {
  assert_grep "reload (prefix+r) com feedback" 'bind r source-file.*display' "$CONF"
}

test_clear_screen_fallback() {
  # C-l é roubado pelo vim-tmux-navigator; prefix+C-l deve recuperar clear
  assert_grep "clear fallback (prefix+C-l)" "bind C-l send-keys 'C-l'" "$CONF"
}

test_default_command_guarded() {
  # Um path absoluto sem guard mata TODO pane com exit 127 em qualquer host
  # sem aquele binário — medido: o servidor inteiro não sobrevive ao boot
  assert_grep "default-command atrás de if-shell" \
    "if-shell '\[ -x /opt/homebrew/bin/reattach-to-user-namespace \]'" "$CONF"
  assert_not_grep "sem set -g default-command solto (não-guarded)" \
    '^set -g default-command' "$CONF"
}

test_pending_mark_guarded() {
  # prefix+m chama um hook externo (~/.claude/hooks/tmux-pending.sh) que só
  # existe na máquina do dono — o guard test -f mantém o binding inofensivo
  # em qualquer clone do repo público
  assert_grep "pending mark (prefix+m)" 'bind-key m run-shell.*tmux-pending.sh mark' "$CONF"
  assert_grep "pending mark tem guard test -f" 'bind-key m run-shell "test -f.*tmux-pending.sh &&' "$CONF"
  # Aba roxa vista por 2s+ apaga ao sair: a troca de aba avisa o hook.
  assert_grep "troca de aba avisa o pending (guarded)" "set-hook -g session-window-changed \"run-shell \\\\\"test -f ~/.claude/hooks/tmux-pending.sh && bash ~/.claude/hooks/tmux-pending.sh window-changed '#\\{session_id\\}' '#\\{window_id\\}'" "$CONF"
  assert_grep "troca de sessão reinicia a contagem (guarded, índice 1)" "set-hook -g 'client-session-changed\\[1\\]' \"run-shell \\\\\"test -f ~/.claude/hooks/tmux-pending.sh && bash ~/.claude/hooks/tmux-pending.sh window-changed" "$CONF"
}

test_copy_mode_vi_bindings() {
  assert_grep "copy-mode v (seleção)" "copy-mode-vi v send -X begin-selection" "$CONF"
  assert_grep "copy-mode C-v (block)" "copy-mode-vi C-v send -X rectangle-toggle" "$CONF"
  assert_grep "copy-mode y (yank pbcopy)" "copy-mode-vi y send -X copy-pipe-and-cancel 'pbcopy'" "$CONF"
}

# ── Status bar ───────────────────────────────────────────────────────────────
test_git_in_status() {
  assert_grep "git branch na status-right" 'git rev-parse --abbrev-ref' "$CONF"
}

# ── Plugins ──────────────────────────────────────────────────────────────────
test_plugins_listed() {
  local plugins=(
    'tmux-plugins/tpm'
    'tmux-plugins/tmux-sensible'
    'tmux-plugins/tmux-resurrect'
    'tmux-plugins/tmux-continuum'
    'tmux-plugins/tmux-yank'
    'tmux-plugins/tmux-open'
    'christoomey/vim-tmux-navigator'
    'laktak/extrakto'
    'omerxx/tmux-sessionx'
  )
  for p in "${plugins[@]}"; do
    if grep -qF "@plugin '$p'" "$CONF"; then
      ok "plugin listado: $p"
    else
      fail "plugin NÃO listado: $p"
    fi
  done
}

test_plugin_vars() {
  assert_grep "@continuum-restore on" "@continuum-restore 'on'" "$CONF"
  assert_grep "@resurrect-strategy-vim session" "@resurrect-strategy-vim 'session'" "$CONF"
  assert_grep "@sessionx-bind O" "@sessionx-bind 'O'" "$CONF"
  assert_grep "@extrakto_key Tab" "@extrakto_key 'Tab'" "$CONF"
  assert_grep "@extrakto_clip_tool pbcopy" "@extrakto_clip_tool 'pbcopy'" "$CONF"
}

test_tpm_init_last_line() {
  # TPM run deve ser a última linha executável; checa que existe.
  assert_grep "TPM init presente" "run '~/.config/tmux/plugins/tpm/tpm'" "$CONF"
}

test_plugin_dirs_installed() {
  # Cada plugin listado deve ter pasta em plugins/. Se não, skip (rodar prefix+I).
  local plugins=(tpm tmux-sensible tmux-resurrect tmux-continuum tmux-yank tmux-open vim-tmux-navigator extrakto tmux-sessionx)
  for p in "${plugins[@]}"; do
    if [[ -d "$PLUGINS_DIR/$p" ]]; then
      ok "plugin instalado: $p"
    else
      skip "plugin não instalado: $p (rode 'prefix + I')"
    fi
  done
}

# ── Preservação de path em bindings ──────────────────────────────────────────
test_new_window_preserves_path() {
  assert_grep "prefix+c preserva cwd" 'bind c new-window -c "#\{pane_current_path\}"' "$CONF"
}

test_splits_preserve_path() {
  assert_grep "split \\ preserva cwd" "bind-key '\\\\' split-window -h -c \"#\\{pane_current_path\\}\"" "$CONF"
  assert_grep "split - preserva cwd" 'bind-key - split-window -v -c "#\{pane_current_path\}"' "$CONF"
}

test_popups_preserve_path() {
  # Todos os popups devem abrir no cwd do pane
  assert_grep "popup C abre no cwd" 'bind-key C display-popup.*-d "#\{pane_current_path\}"' "$CONF"
  assert_grep "popup G abre no cwd" 'bind-key G display-popup.*-d "#\{pane_current_path\}"' "$CONF"
  assert_grep "popup T abre no cwd" 'bind-key T display-popup.*-d "#\{pane_current_path\}"' "$CONF"
}

test_popups_have_E_flag() {
  # -E fecha popup quando processo sai. Sem isso, popup vira zombie.
  assert_grep "popup C tem -E" 'bind-key C display-popup -E' "$CONF"
  assert_grep "popup G tem -E" 'bind-key G display-popup -E' "$CONF"
  assert_grep "popup T tem -E" 'bind-key T display-popup -E' "$CONF"
}

test_send_prefix_binding() {
  assert_grep "send-prefix bind (prefix+C-a literal)" 'bind-key C-a send-prefix' "$CONF"
}

# ── Consistência temática (invariantes cruzados) ─────────────────────────────
test_vi_theme_unified() {
  # mode-keys, @shell_mode, status-keys — todos vi
  assert_grep "mode-keys vi (vi theme)" 'setw -g mode-keys vi' "$CONF"
  assert_grep "@shell_mode vi (vi theme)" "@shell_mode 'vi'" "$CONF"
  assert_grep "status-keys vi (vi theme, post-TPM)" '^set -g status-keys vi' "$CONF"
}

test_pbcopy_everywhere() {
  # Clipboard macOS usado consistentemente
  assert_grep "copy-mode y → pbcopy" "copy-pipe-and-cancel 'pbcopy'" "$CONF"
  assert_grep "@extrakto_clip_tool pbcopy" "@extrakto_clip_tool 'pbcopy'" "$CONF"
}

test_true_color_chain_complete() {
  # Os 4 componentes precisam estar presentes JUNTOS
  assert_grep "tmux-256color (chain)" 'default-terminal "tmux-256color"' "$CONF"
  assert_grep "RGB override (chain)" 'terminal-overrides.*:RGB' "$CONF"
  assert_grep "Smulx (chain)" 'Smulx' "$CONF"
  assert_grep "Setulc (chain)" 'Setulc' "$CONF"
}

# ── Regressões específicas adicionais ────────────────────────────────────────
test_status_left_length_60() {
  # status-left-length era 20 (original); precisou subir pra 60 pra caber a lista de sessões
  assert_grep "status-left-length 60" 'set -g status-left-length 60' "$CONF"
}

test_window_status_format_no_hardcoded_bg() {
  # Regressão: antes tinha `bg=black` e `bg=default` hardcoded no formato inativo;
  # agora o global é neutro (sem bg explícito) para herdar o status-bg da sessão.
  assert_not_grep "window-status-format não tem bg=black hardcoded" 'window-status-format.*bg=black' "$CONF"
}

test_current_format_global_is_neutral() {
  # A intenção original continua: nenhuma cor de sessão pode VAZAR para outra
  # sessão. O mecanismo mudou — antes o global era neutro (colour244) e o
  # tema pintava por window; agora o global carrega as três paletas atrás de
  # condicionais de formato resolvidas por #S no render, o que elimina o
  # flash entre criar a janela e o hook rodar (não há mais hook).
  assert_grep "window-status-current-format global mantém o neutro (colour244)" 'window-status-current-format.*colour244' "$CONF"
  assert_grep "window-status-current-format global é condicional por sessão" 'window-status-current-format.*m:work\*' "$CONF"
  assert_grep "window-status-format global também é condicional por sessão" 'window-status-format.*m:personal\*' "$CONF"
}

test_session_theme_has_window_status_formats() {
  # As duas paletas continuam definidas — só mudaram de arquivo, do
  # session-theme.sh para o global do conf, quando a pintura por-window
  # passou a ser exclusividade do indicador de pendência (26/08/2026).
  assert_grep "paleta de work (ciano) no current-format global" 'window-status-current-format.*colour51.*colour31|window-status-current-format.*colour31.*colour51' "$CONF"
  assert_grep "paleta de personal (laranja) no current-format global" 'window-status-current-format.*colour172.*colour130|window-status-current-format.*colour130.*colour172' "$CONF"
}

test_session_theme_reset_default_case() {
  # A regressão original (renomear work→foo deixava cores de work grudadas)
  # deixou de ser possível por construção: o formato global resolve a cor
  # por #S a cada render, então renomear a sessão troca a cor sozinho, sem
  # nada pra "resetar". A asserção agora é a inversa e mais forte —
  # session-theme.sh NÃO pode escrever formato de window, porque esse escopo
  # é do indicador de pendência e dois donos ali se atropelam (foi o bug das
  # "windows cinzas" em 25/08/2026).
  local script
  script="$(dirname "$CONF")/scripts/session-theme.sh"
  # ^[^#]* ancora fora de comentário: a primeira versão desta asserção casava
  # com a própria linha de comentário que EXPLICA a mudança, medindo texto em
  # vez de comportamento.
  assert_not_grep "session-theme não escreve window-status (escopo do indicador)" '^[^#]*tmux.*window-status' "$script"
  assert_grep "session-theme segue cuidando das opções de SESSÃO" 'status-bg' "$script"
}

# ── Ranges de sanidade numérica ──────────────────────────────────────────────
test_status_interval_in_range() {
  local v
  v=$(grep -oE 'set -g status-interval [0-9]+' "$CONF" | awk '{print $NF}')
  if [[ -z "$v" ]]; then
    fail "status-interval não encontrado"
  elif [[ $v -ge 1 && $v -le 60 ]]; then
    ok "status-interval razoável ($v s ∈ [1,60])"
  else
    fail "status-interval fora de range: $v" "esperado [1,60]"
  fi
}

test_history_limit_in_range() {
  local v
  v=$(grep -oE 'set -g history-limit [0-9]+' "$CONF" | awk '{print $NF}')
  if [[ -z "$v" ]]; then
    fail "history-limit não encontrado"
  elif [[ $v -ge 1000 && $v -le 500000 ]]; then
    ok "history-limit razoável ($v ∈ [1000,500000])"
  else
    fail "history-limit fora de range: $v" "esperado [1000,500000]"
  fi
}

test_popup_sizes_sane() {
  # Extrai todas as larguras/alturas dos popups
  local sizes
  sizes=$(grep -oE -- '-[wh] [0-9]+%' "$CONF" | grep -oE '[0-9]+')
  if [[ -z "$sizes" ]]; then
    fail "nenhum popup com -w/-h % encontrado"
    return
  fi
  local bad=0
  while IFS= read -r size; do
    if ! [[ $size -ge 30 && $size -le 95 ]]; then
      bad=$((bad + 1))
      fail "popup size fora de [30,95]: $size%"
    fi
  done <<< "$sizes"
  [[ $bad -eq 0 ]] && ok "todas dimensões de popup ∈ [30%, 95%]"
}

# ── Var plugin presence via grep (complementa integration runtime) ───────────
test_plugin_vars_presence() {
  assert_grep "@shell_mode presente" "@shell_mode 'vi'" "$CONF"
  assert_grep "@open presente" "@open 'C-o'" "$CONF"
  assert_grep "@open-editor presente" "@open-editor 'o'" "$CONF"
  assert_grep "@sessionx-window-mode presente" "@sessionx-window-mode 'on'" "$CONF"
  assert_grep "@sessionx-preview-enabled presente" "@sessionx-preview-enabled 'true'" "$CONF"
  assert_grep "@extrakto_default_opt presente" "@extrakto_default_opt 'word'" "$CONF"
}

# ── Entry point da suite ─────────────────────────────────────────────────────
suite_shell() {
  reset_suite_counters
  test_conf_exists
  test_readme_exists
  test_cheatsheet_exists
  test_no_bgbright_typo
  test_no_empty_bg_attr
  test_no_screen_256color
  test_no_monitor_activity_on
  test_status_left_shows_sessions
  test_status_left_no_strftime_percent_s
  test_status_left_no_comma_in_bold_attr
  test_status_left_length_60
  test_window_0_mapped_to_10
  test_rename_session_no_shift
  test_no_vs_splits
  test_prefix_binding
  test_base_index
  test_vi_modes
  test_mouse_and_focus
  test_history_limit
  test_true_color
  test_undercurl
  test_modern_splits
  test_swap_window_bindings
  test_session_theme_hooks
  test_session_theme_script_exists
  test_popup_bindings
  test_reload_binding
  test_clear_screen_fallback
  test_default_command_guarded
  test_pending_mark_guarded
  test_copy_mode_vi_bindings
  test_git_in_status
  test_plugins_listed
  test_plugin_vars
  test_tpm_init_last_line
  test_plugin_dirs_installed
  # Path preservation
  test_new_window_preserves_path
  test_splits_preserve_path
  test_popups_preserve_path
  test_popups_have_E_flag
  test_send_prefix_binding
  # Consistency
  test_vi_theme_unified
  test_pbcopy_everywhere
  test_true_color_chain_complete
  # Specific regressions
  test_window_status_format_no_hardcoded_bg
  test_current_format_global_is_neutral
  test_session_theme_has_window_status_formats
  test_session_theme_reset_default_case
  # Sanity ranges
  test_status_interval_in_range
  test_history_limit_in_range
  test_popup_sizes_sane
  # Plugin vars (grep)
  test_plugin_vars_presence
}
