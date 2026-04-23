#!/usr/bin/env bash
# Assertion helpers compartilhados entre suites.
# Expõe: ok / fail / skip / counters / cores.
# Variáveis VERBOSE e cores são herdadas de run.sh via `source`.

# Counters (globais pra agregação através das suites)
TOTAL_PASS=${TOTAL_PASS:-0}
TOTAL_FAIL=${TOTAL_FAIL:-0}
TOTAL_SKIP=${TOTAL_SKIP:-0}
SUITE_PASS=0
SUITE_FAIL=0
SUITE_SKIP=0
FAIL_MESSAGES=()

ok() {
  SUITE_PASS=$((SUITE_PASS + 1))
  TOTAL_PASS=$((TOTAL_PASS + 1))
  if [[ ${VERBOSE:-0} -ge 1 ]]; then
    printf "    %b✓%b %s\n" "$GREEN" "$RESET" "$1"
  fi
}

fail() {
  SUITE_FAIL=$((SUITE_FAIL + 1))
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
  FAIL_MESSAGES+=("$1")
  if [[ ${VERBOSE:-0} -ge 1 ]]; then
    printf "    %b✗%b %s\n" "$RED" "$RESET" "$1"
    [[ -n "${2:-}" ]] && printf "      %b%s%b\n" "$DIM" "$2" "$RESET"
  fi
}

skip() {
  SUITE_SKIP=$((SUITE_SKIP + 1))
  TOTAL_SKIP=$((TOTAL_SKIP + 1))
  if [[ ${VERBOSE:-0} -ge 1 ]]; then
    printf "    %b~%b %s\n" "$YELLOW" "$RESET" "$1"
  fi
}

# Helpers de asserção
assert_match() {
  local label=$1 haystack=$2 needle=$3
  if [[ "$haystack" == *"$needle"* ]]; then
    ok "$label"
  else
    fail "$label" "esperado contém: $needle"
  fi
}

assert_not_match() {
  local label=$1 haystack=$2 needle=$3
  if [[ "$haystack" != *"$needle"* ]]; then
    ok "$label"
  else
    fail "$label" "não deveria conter: $needle"
  fi
}

assert_grep() {
  local label=$1 pattern=$2 file=$3
  if grep -qE -- "$pattern" "$file"; then
    ok "$label"
  else
    fail "$label" "padrão ausente em $file: $pattern"
  fi
}

assert_not_grep() {
  local label=$1 pattern=$2 file=$3
  if ! grep -qE -- "$pattern" "$file"; then
    ok "$label"
  else
    local hit
    hit=$(grep -nE -- "$pattern" "$file" | head -1)
    fail "$label" "padrão presente em $file: $hit"
  fi
}

assert_eq() {
  local label=$1 actual=$2 expected=$3
  if [[ "$actual" == "$expected" ]]; then
    ok "$label"
  else
    fail "$label" "esperado: '$expected' | atual: '$actual'"
  fi
}

# Reseta counters da suite atual (chamar ANTES de rodar tests da suite)
reset_suite_counters() {
  SUITE_PASS=0
  SUITE_FAIL=0
  SUITE_SKIP=0
  FAIL_MESSAGES=()
}
