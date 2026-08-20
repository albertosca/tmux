#!/usr/bin/env bash
# Publish this config to the public mirror at github.com/albertosca/tmux.
#
# The mirror is a separate repository, not a subtree push: the public history
# was rewritten with git filter-repo, so `git subtree push` recreates SHAs on
# every run and would demand a force push. Copying into a fresh clone keeps
# the public history linear and append-only.
#
# The private dotfiles monorepo is never the public remote. Only the file set
# below is ever published — an allowlist, never a denylist, so a file added to
# the repo stays private until someone deliberately lists it.
#
# Usage:
#   bash scripts/sync-public.sh              # sync if drifted
#   bash scripts/sync-public.sh --check      # report drift, change nothing (exit 1 = drifted)
#   bash scripts/sync-public.sh --fingerprint # print the fingerprint and exit
#
# --fingerprint exists so the SessionStart nudge hook can ask THIS script for
# the hash instead of reimplementing it. Two implementations of the same hash
# silently disagree, and a nudge that can never be cleared gets ignored.

set -euo pipefail

SRC="${TMUX_CONFIG_SRC:-$HOME/.dotfiles/config/tmux}"
REMOTE="${TMUX_PUBLIC_REMOTE:-git@github.com:albertosca/tmux.git}"
STATE_FILE="$SRC/.public-sync"

# Everything published, relative to $SRC. Anything absent from this list never
# reaches the public repo — that is the privacy boundary, so it is a explicit
# allowlist and never a denylist.
PUBLISHED=(
  tmux.conf
  README.md
  README.pt.md
  CHEATSHEET.md
  CLAUDE.md
  .gitignore
  .github
  scripts
  test
)

# Fingerprint of the published file set only. The state file, the local
# .claude/ settings and the TPM plugins/ dir are excluded by construction:
# they are not in PUBLISHED, so they never move the fingerprint.
#
# Paths are hashed relative to $SRC alongside the bytes: relative so the hash
# does not change when the checkout moves, and path-sensitive so a pure
# rename registers as drift instead of hashing identical.
fingerprint() {
  local f
  {
    for f in "${PUBLISHED[@]}"; do
      [ -e "$SRC/$f" ] || continue
      find "$SRC/$f" -type f -print 2>/dev/null
    done | sed "s|^$SRC/||" | LC_ALL=C sort | while IFS= read -r rel; do
      printf '%s\0' "$rel"
      shasum "$SRC/$rel" | awk '{print $1}'
    done
  } | shasum | awk '{print $1}'
}

current=$(fingerprint)

if [ "${1:-}" = "--fingerprint" ]; then
  printf '%s\n' "$current"
  exit 0
fi
recorded=$(cat "$STATE_FILE" 2>/dev/null || echo "none")

if [ "$current" = "$recorded" ]; then
  echo "public mirror in sync (fingerprint ${current:0:12})"
  exit 0
fi

if [ "${1:-}" = "--check" ]; then
  echo "DRIFTED: local tmux config differs from the last published state"
  echo "  recorded: ${recorded:0:12}"
  echo "  current:  ${current:0:12}"
  echo "  fix with: bash $SRC/scripts/sync-public.sh"
  exit 1
fi

echo "==> running the test suite before publishing"
if ! bash "$SRC/test/run.sh" >/dev/null 2>&1; then
  echo "ABORTED: test suite is red — refusing to publish" >&2
  echo "  run 'bash $SRC/test/run.sh' to see what broke" >&2
  exit 1
fi
echo "    suite green"

if command -v shellcheck >/dev/null 2>&1; then
  echo "==> shellcheck"
  if ! shellcheck -S warning "$SRC"/scripts/*.sh "$SRC"/test/*.sh; then
    echo "ABORTED: shellcheck is red — refusing to publish" >&2
    exit 1
  fi
  echo "    clean"
fi

tmpdir=$(mktemp -d -t tmux-public.XXXXXX)
trap 'rm -rf "$tmpdir"' EXIT

echo "==> cloning the public mirror"
git clone --quiet "$REMOTE" "$tmpdir/repo"

# Mirror deletions too: wipe the published paths, then copy the current set.
# Copying over a stale checkout would leave a file that was deleted locally
# alive in the public repo forever.
for f in "${PUBLISHED[@]}"; do
  rm -rf "${tmpdir:?}/repo/${f:?}"
done
for f in "${PUBLISHED[@]}"; do
  [ -e "$SRC/$f" ] || continue
  cp -R "$SRC/$f" "$tmpdir/repo/$f"
done

cd "$tmpdir/repo"
if [ -z "$(git status --porcelain)" ]; then
  echo "==> mirror already matches; recording fingerprint"
  printf '%s\n' "$current" > "$STATE_FILE"
  exit 0
fi

echo "==> changes to publish:"
git --no-pager status --short

git add -A
git commit --quiet -m "$(cat <<'EOF'
sync: publish current tmux config from the private dotfiles

Mirrors the live config. Synced by scripts/sync-public.sh.
EOF
)"
git push --quiet origin HEAD
echo "==> pushed to $REMOTE"

printf '%s\n' "$current" > "$STATE_FILE"
echo "==> recorded fingerprint ${current:0:12}"
