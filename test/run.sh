#!/usr/bin/env bash
# Entry point da suite de testes do tmux config.
# Uso:
#   bash test/run.sh              → roda tudo (compacto, uma linha por suite)
#   bash test/run.sh shell        → só shell suite
#   bash test/run.sh integration  → só integration suite
#   bash test/run.sh -v           → cada caso com ✓/✗
#   bash test/run.sh -vv          → modo verbose com stderr de tmux em falhas
#   bash test/run.sh shell -v     → uma suite, expandida

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$TEST_DIR" || exit 1

# ── Args ─────────────────────────────────────────────────────────────────────
SUITE="all"
VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    -vv|--raw)     VERBOSE=2 ;;
    -v|--verbose)  VERBOSE=1 ;;
    -h|--help)
      sed -n '2,10p' "${BASH_SOURCE[0]}"
      exit 0 ;;
    *)             SUITE="$arg" ;;
  esac
done
export VERBOSE

# ── Colors ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  DIM='\033[2m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' RED='' YELLOW='' DIM='' BOLD='' RESET=''
fi
export GREEN RED YELLOW DIM BOLD RESET

# ── Portable millisecond timer ───────────────────────────────────────────────
now_ms() {
  python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null \
    || perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000' 2>/dev/null \
    || echo $(( $(date +%s) * 1000 ))
}

# ── Load helpers ─────────────────────────────────────────────────────────────
source ./lib.sh

# ── Visuals ──────────────────────────────────────────────────────────────────
SEP='─────────────────────────────────────────────────────'

suite_line() {
  local name="$1" pass="$2" fail="$3" skip="${4:-0}" elapsed_ms="$5"

  local elapsed
  elapsed=$(awk "BEGIN { printf \"%.1f\", $elapsed_ms / 1000 }")

  local icon color
  if [[ "$fail" -gt 0 ]]; then
    icon="✗" ; color="$RED"
  else
    icon="✓" ; color="$GREEN"
  fi

  local skip_str=""
  if [[ "$skip" -gt 0 ]]; then
    skip_str="  ${YELLOW}${skip} skipped${RESET}"
  fi

  local fail_color
  [[ "$fail" -gt 0 ]] && fail_color="$RED" || fail_color="$DIM"

  printf "  %b%s%b  %-14s %b%s passed%b%b  %b%s failed%b  %b%s%b\n" \
    "$color" "$icon" "$RESET" \
    "$name" \
    "$GREEN" "$pass" "$RESET" \
    "$skip_str" \
    "$fail_color" "$fail" "$RESET" \
    "$DIM" "${elapsed}s" "$RESET"
}

# ── Suite runner ─────────────────────────────────────────────────────────────
run_suite() {
  local name=$1
  local file="./$name.sh"

  if [[ ! -f "$file" ]]; then
    printf "  %berror:%b unknown suite '%s' (expected: shell, integration)\n" "$RED" "$RESET" "$name" >&2
    return 2
  fi

  local pass_before=$TOTAL_PASS fail_before=$TOTAL_FAIL skip_before=$TOTAL_SKIP
  local start elapsed
  start=$(now_ms)

  [[ $VERBOSE -ge 1 ]] && printf "\n  %b%s%b\n" "$BOLD" "$name" "$RESET"

  # shellcheck disable=SC1090
  source "$file"
  "suite_$name"

  elapsed=$(( $(now_ms) - start ))
  local sp=$((TOTAL_PASS - pass_before))
  local sf=$((TOTAL_FAIL - fail_before))
  local ss=$((TOTAL_SKIP - skip_before))

  if [[ $VERBOSE -eq 0 ]]; then
    suite_line "$name" "$sp" "$sf" "$ss" "$elapsed"
    # Em modo compacto, se falhou, lista os nomes dos casos
    if [[ $sf -gt 0 ]]; then
      for msg in "${FAIL_MESSAGES[@]}"; do
        printf "      %b✗%b %s\n" "$RED" "$RESET" "$msg"
      done
    fi
  fi
}

# ── Header ───────────────────────────────────────────────────────────────────
printf "\n"
printf "  %btmux Config Test Suite%b\n" "$BOLD" "$RESET"
printf "  %b%s%b\n" "$DIM" "$SEP" "$RESET"

# ── Dispatch ────────────────────────────────────────────────────────────────
case "$SUITE" in
  all)
    run_suite shell
    run_suite structure
    run_suite integration
    run_suite meta
    ;;
  shell|structure|integration|meta)
    run_suite "$SUITE"
    ;;
  *)
    printf "  %berror:%b unknown suite '%s'\n" "$RED" "$RESET" "$SUITE" >&2
    exit 2
    ;;
esac

# ── Summary ─────────────────────────────────────────────────────────────────
printf "\n"
printf "  %b%s%b\n" "$DIM" "$SEP" "$RESET"
if [[ $TOTAL_FAIL -eq 0 ]]; then
  printf "  %b✓ %s passed%b   %ball green%b" \
    "${BOLD}${GREEN}" "$TOTAL_PASS" "$RESET" \
    "$DIM" "$RESET"
  [[ $TOTAL_SKIP -gt 0 ]] && printf "   %b%s skipped%b" "$YELLOW" "$TOTAL_SKIP" "$RESET"
  printf "\n"
else
  printf "  %b✗ %s passed   %s failed%b" \
    "${BOLD}${RED}" "$TOTAL_PASS" "$TOTAL_FAIL" "$RESET"
  [[ $TOTAL_SKIP -gt 0 ]] && printf "   %b%s skipped%b" "$YELLOW" "$TOTAL_SKIP" "$RESET"
  printf "\n"
fi
printf "\n"

exit "$([[ $TOTAL_FAIL -eq 0 ]] && echo 0 || echo 1)"
