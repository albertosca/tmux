#!/usr/bin/env bash
# Structure suite — invariantes estruturais e file-level.
# Detecta: line-order errados, duplicatas, arquivos corrompidos, plugin health.

CONF="$HOME/.config/tmux/tmux.conf"
PLUGINS_DIR="$HOME/.config/tmux/plugins"

# ── Line-order invariants ────────────────────────────────────────────────────
test_tpm_run_exists() {
  local count
  count=$(grep -c "^run '~/.config/tmux/plugins/tpm/tpm'" "$CONF" || true)
  if [[ "${count:-0}" -eq 1 ]]; then
    ok "TPM run line existe (exatamente 1)"
  else
    fail "TPM run line errado" "esperado 1, encontrado $count"
  fi
}

test_tpm_is_last_run() {
  # Nenhum outro `run '...'` deve vir DEPOIS do tpm run
  local tpm_line last_run_line
  tpm_line=$(grep -nE "^run '~/.config/tmux/plugins/tpm/tpm'" "$CONF" | cut -d: -f1)
  last_run_line=$(grep -nE "^run(-shell)? '" "$CONF" | tail -1 | cut -d: -f1)
  if [[ "$tpm_line" == "$last_run_line" ]]; then
    ok "TPM é o último run no conf (line $tpm_line)"
  else
    fail "algum 'run' depois do TPM" "tpm=$tpm_line, último=$last_run_line"
  fi
}

test_status_keys_after_tpm() {
  # O override post-TPM DEVE vir depois do run TPM
  local tpm_line status_line
  tpm_line=$(grep -nE "^run '~/.config/tmux/plugins/tpm/tpm'" "$CONF" | cut -d: -f1)
  status_line=$(grep -nE "^set -g status-keys vi" "$CONF" | head -1 | cut -d: -f1)
  if [[ -z "$tpm_line" || -z "$status_line" ]]; then
    fail "linhas não encontradas" "tpm=$tpm_line status=$status_line"
  elif [[ $status_line -gt $tpm_line ]]; then
    ok "status-keys vi APÓS tpm run (linha $status_line > $tpm_line)"
  else
    fail "status-keys vi ANTES de tpm (seria sobrescrito por sensible)" \
         "status=$status_line, tpm=$tpm_line"
  fi
}

test_post_tpm_section_present() {
  assert_grep "Seção Post-TPM overrides documentada" "Post-TPM" "$CONF"
}

# ── Plugin contagem + formato ────────────────────────────────────────────────
test_plugin_count_exact() {
  local count
  count=$(grep -cE "^set -g @plugin '" "$CONF" || true)
  if [[ ${count:-0} -eq 9 ]]; then
    ok "exatamente 9 plugins (count=9)"
  else
    fail "plugin count inesperado: $count" "esperado 9 — se adicionou/removeu, atualize este teste"
  fi
}

test_example_plugins_commented() {
  # Linhas de exemplo em 164-168 devem permanecer comentadas
  local bad
  bad=$(grep -E "^set -g @plugin 'github_username" "$CONF" || true)
  if [[ -z "$bad" ]]; then
    ok "linhas de exemplo @plugin permanecem comentadas"
  else
    fail "exemplo @plugin descomentado" "$bad"
  fi
}

test_plugin_urls_format() {
  # Todos @plugin devem seguir 'user/repo' (não git@, não http://)
  local bad=0
  while IFS= read -r url; do
    if ! [[ "$url" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
      fail "plugin URL malformado: $url"
      bad=$((bad + 1))
    fi
  done < <(grep -E "^set -g @plugin '" "$CONF" | awk -F"'" '{print $2}')
  [[ $bad -eq 0 ]] && ok "todos plugin URLs no formato user/repo"
}

test_tpm_env_var_set() {
  assert_grep "TMUX_PLUGIN_MANAGER_PATH definido" \
    "set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.config/tmux/plugins'" "$CONF"
}

test_tpm_auto_install_block() {
  # Bloco if-shell de auto-install tpm (linhas 127-128)
  assert_grep "auto-install block do TPM presente" \
    "test ! -d ~/.config/tmux/plugins/tpm" "$CONF"
  assert_grep "auto-install clona TPM" \
    "git clone https://github.com/tmux-plugins/tpm" "$CONF"
}

# ── Duplicate detection ──────────────────────────────────────────────────────
test_no_duplicate_bindings() {
  # Extrai (tabela, key) de cada bind-key e detecta duplicatas
  local dups
  dups=$(awk '
    /^\s*#/ { next }
    /^bind(-key)? / {
      table = "prefix"
      key = ""
      for (i = 2; i <= NF; i++) {
        if ($i == "-n") { table = "root"; continue }
        if ($i == "-T") { table = $(i+1); i++; continue }
        if ($i == "-r") continue
        key = $i
        break
      }
      if (key != "") print table "|" key
    }
  ' "$CONF" | sort | uniq -d)

  if [[ -z "$dups" ]]; then
    ok "nenhum bind-key duplicado (tabela+key únicos)"
  else
    fail "bindings duplicados" "$(echo "$dups" | tr '\n' ' ')"
  fi
}

test_no_duplicate_set_left() {
  # Regressão: antes tínhamos set -g status-left '' duas vezes
  local count
  count=$(grep -cE "^[^#]*set -g status-left ''" "$CONF" || true)
  if [[ ${count:-0} -le 1 ]]; then
    ok "sem duplicata de 'set -g status-left '' (count=$count)"
  else
    fail "duplicata de status-left" "aparece $count vezes"
  fi
}

# ── Arquivo: encoding, permissões, line endings ──────────────────────────────
test_utf8_valid() {
  if iconv -f UTF-8 -t UTF-8 "$CONF" >/dev/null 2>&1; then
    ok "arquivo é UTF-8 válido"
  else
    fail "arquivo não é UTF-8 válido" "os chars ⮀ ⮁ requerem UTF-8"
  fi
}

test_no_bom() {
  local bom
  bom=$(head -c 3 "$CONF" | od -An -tx1 | tr -d ' ')
  if [[ "$bom" != "efbbbf" ]]; then
    ok "arquivo sem BOM UTF-8"
  else
    fail "BOM UTF-8 presente no início do arquivo"
  fi
}

test_no_crlf() {
  if grep -q $'\r' "$CONF"; then
    fail "line endings CRLF presentes" "use LF (Unix)"
  else
    ok "line endings Unix (LF)"
  fi
}

test_permissions_644() {
  local perms
  if [[ "$(uname)" == "Darwin" ]]; then
    perms=$(stat -f '%Lp' "$CONF")
  else
    perms=$(stat -c '%a' "$CONF")
  fi
  if [[ "$perms" == "644" ]]; then
    ok "permissões 644"
  else
    fail "permissões inesperadas: $perms" "esperado 644"
  fi
}

test_line_count_reasonable() {
  local lines
  lines=$(wc -l < "$CONF")
  if [[ $lines -lt 300 ]]; then
    ok "line count razoável ($lines < 300)"
  else
    fail "conf muito grande: $lines linhas" "considere refatorar"
  fi
}

# ── Ambiente externo ─────────────────────────────────────────────────────────
test_no_legacy_tmux_conf() {
  # ~/.tmux.conf sombreia o XDG path em alguns tmux
  if [[ -e "$HOME/.tmux.conf" ]]; then
    fail "~/.tmux.conf existe" "pode sombrear ~/.config/tmux/tmux.conf"
  else
    ok "~/.tmux.conf ausente (XDG path ativo sem conflito)"
  fi
}

# ── Plugin health ────────────────────────────────────────────────────────────
test_plugin_dirs_valid_git_repos() {
  local plugins=(tpm tmux-sensible tmux-resurrect tmux-continuum tmux-yank tmux-open vim-tmux-navigator extrakto tmux-sessionx)
  for p in "${plugins[@]}"; do
    local dir="$PLUGINS_DIR/$p"
    if [[ ! -d "$dir" ]]; then
      skip "plugin não instalado: $p"
      continue
    fi
    if [[ -d "$dir/.git" ]]; then
      ok "$p: git repo válido"
    else
      fail "$p: dir sem .git" "$(ls -la "$dir" | head -5)"
    fi
  done
}

test_plugin_dirs_have_entry_file() {
  # Cada plugin (exceto tpm/manager) deve ter um arquivo .tmux
  local plugins=(tmux-sensible tmux-resurrect tmux-continuum tmux-yank tmux-open vim-tmux-navigator extrakto tmux-sessionx)
  for p in "${plugins[@]}"; do
    local dir="$PLUGINS_DIR/$p"
    if [[ ! -d "$dir" ]]; then
      skip "plugin não instalado: $p"
      continue
    fi
    if compgen -G "$dir/*.tmux" > /dev/null; then
      ok "$p: arquivo .tmux encontrado"
    else
      fail "$p: sem arquivo .tmux" "plugin não vai carregar via TPM"
    fi
  done
}

test_no_orphan_plugin_dirs() {
  # Dirs em plugins/ devem todos estar listados no conf
  if [[ ! -d "$PLUGINS_DIR" ]]; then
    skip "plugins/ dir ausente"
    return
  fi
  local listed=()
  while IFS= read -r url; do
    listed+=("$(basename "$url")")
  done < <(grep -E "^set -g @plugin '" "$CONF" | awk -F"'" '{print $2}')
  listed+=(tpm)  # tpm sempre ok

  local orphans=()
  for dir in "$PLUGINS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local name
    name=$(basename "$dir")
    local found=0
    for l in "${listed[@]}"; do
      [[ "$l" == "$name" ]] && { found=1; break; }
    done
    [[ $found -eq 0 ]] && orphans+=("$name")
  done

  if [[ ${#orphans[@]} -eq 0 ]]; then
    ok "sem dirs órfãos em plugins/"
  else
    fail "dirs órfãos em plugins/" "${orphans[*]}"
  fi
}

# ── Entry point ─────────────────────────────────────────────────────────────
suite_structure() {
  reset_suite_counters
  # Line-order
  test_tpm_run_exists
  test_tpm_is_last_run
  test_status_keys_after_tpm
  test_post_tpm_section_present
  # Plugin structure
  test_plugin_count_exact
  test_example_plugins_commented
  test_plugin_urls_format
  test_tpm_env_var_set
  test_tpm_auto_install_block
  # Duplicates
  test_no_duplicate_bindings
  test_no_duplicate_set_left
  # File integrity
  test_utf8_valid
  test_no_bom
  test_no_crlf
  test_permissions_644
  test_line_count_reasonable
  # External
  test_no_legacy_tmux_conf
  # Plugin health
  test_plugin_dirs_valid_git_repos
  test_plugin_dirs_have_entry_file
  test_no_orphan_plugin_dirs
}
