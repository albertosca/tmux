#!/usr/bin/env bash
# Meta suite — testa o próprio test infra.
# Garante que o harness não regride (help, exit codes, cleanup, carregamento).

TEST_DIR_META="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SH="$TEST_DIR_META/run.sh"

# ── Existência + executabilidade ─────────────────────────────────────────────
test_run_sh_exists() {
  [[ -f "$RUN_SH" && -r "$RUN_SH" ]] \
    && ok "run.sh existe e é legível" \
    || fail "run.sh faltando ou ilegível"
}

test_suite_files_exist() {
  for s in shell structure integration; do
    if [[ -f "$TEST_DIR_META/$s.sh" ]]; then
      ok "suite file: $s.sh"
    else
      fail "suite file ausente: $s.sh"
    fi
  done
}

test_lib_sh_sourceable() {
  # Sintaxe válida — bash -n verifica sem executar
  if bash -n "$TEST_DIR_META/lib.sh" 2>/dev/null; then
    ok "lib.sh sintaticamente válido"
  else
    fail "lib.sh com erro de sintaxe" "$(bash -n "$TEST_DIR_META/lib.sh" 2>&1)"
  fi
}

test_all_suites_syntactically_valid() {
  for s in shell structure integration meta; do
    local f="$TEST_DIR_META/$s.sh"
    [[ -f "$f" ]] || continue
    if bash -n "$f" 2>/dev/null; then
      ok "$s.sh sintaticamente válido"
    else
      fail "$s.sh erro de sintaxe" "$(bash -n "$f" 2>&1)"
    fi
  done
}

# ── Comportamento de run.sh ──────────────────────────────────────────────────
test_unknown_suite_exits_nonzero() {
  # Suite inexistente deve falhar (exit != 0)
  bash "$RUN_SH" suite_fake_inexistente >/dev/null 2>&1
  local code=$?
  if [[ $code -ne 0 ]]; then
    ok "suite desconhecida retorna exit $code (não-zero)"
  else
    fail "suite desconhecida retornou 0" "deveria falhar"
  fi
}

test_help_flag_works() {
  local out
  out=$(bash "$RUN_SH" -h 2>&1)
  if echo "$out" | grep -qE "bash test/run.sh"; then
    ok "-h imprime usage"
  else
    fail "-h não imprimiu usage" "output: $(echo "$out" | head -3)"
  fi
}

# ── Cleanup invariantes ──────────────────────────────────────────────────────
test_integration_defines_cleanup() {
  if grep -q "^cleanup_integration()" "$TEST_DIR_META/integration.sh"; then
    ok "cleanup_integration() definido"
  else
    fail "cleanup_integration() não definido em integration.sh"
  fi
}

test_integration_calls_cleanup_at_end() {
  # A função suite_integration deve chamar cleanup_integration no fim
  if grep -qE "^\s+cleanup_integration$" "$TEST_DIR_META/integration.sh"; then
    ok "suite_integration chama cleanup no fim"
  else
    fail "cleanup não é chamado em suite_integration"
  fi
}

test_integration_uses_pid_socket() {
  # Socket deve ser isolado por PID
  if grep -qE 'SOCKET="claude-test-\$\$"' "$TEST_DIR_META/integration.sh"; then
    ok "socket isolado por PID (claude-test-\$\$)"
  else
    fail "socket sem isolamento por PID" "risco de colisão em runs paralelos"
  fi
}

test_no_socket_leak_after_integration() {
  # Roda integration num subprocess e verifica que não sobrou socket
  local tmpdir="${TMUX_TMPDIR:-/tmp/tmux-$(id -u)}"
  [[ -d "$tmpdir" ]] || { skip "tmux tmpdir não existe"; return; }

  local before after
  before=$(find "$tmpdir" -maxdepth 1 -name "claude-test-*" 2>/dev/null | wc -l | tr -d ' ')
  bash "$RUN_SH" integration >/dev/null 2>&1
  after=$(find "$tmpdir" -maxdepth 1 -name "claude-test-*" 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$after" -eq "$before" ]]; then
    ok "nenhum socket vazado após integration ($after sockets claude-test-*)"
  else
    fail "socket leak detectado" "before=$before after=$after"
  fi
}

# ── Suite entry points existem ───────────────────────────────────────────────
test_all_suites_define_entry_function() {
  local pairs=(
    "shell:suite_shell"
    "structure:suite_structure"
    "integration:suite_integration"
    "meta:suite_meta"
  )
  for pair in "${pairs[@]}"; do
    local file="${pair%:*}.sh"
    local fn="${pair#*:}"
    if grep -qE "^${fn}\(\)" "$TEST_DIR_META/$file"; then
      ok "$file define $fn()"
    else
      fail "$file sem função $fn()"
    fi
  done
}

# ── Entry point ─────────────────────────────────────────────────────────────
suite_meta() {
  reset_suite_counters
  test_run_sh_exists
  test_suite_files_exist
  test_lib_sh_sourceable
  test_all_suites_syntactically_valid
  test_unknown_suite_exits_nonzero
  test_help_flag_works
  test_integration_defines_cleanup
  test_integration_calls_cleanup_at_end
  test_integration_uses_pid_socket
  test_no_socket_leak_after_integration
  test_all_suites_define_entry_function
}
