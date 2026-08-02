#!/usr/bin/env bash
# Ad-hoc verification template.
#
# Usage:
#   1. Edit the CONFIG block below for your repo + changed files + checks
#   2. Save as /tmp/hermes-verify-<slug>.sh
#   3. chmod +x ... && run
#   4. rm -f when done
#
# Conventions:
#   - set -u only (not -e — we want to count failures, not abort)
#   - quoted heredoc delimiter ('OUTER') prevents shell variable expansion
#   - match-strings should be checked against a real run first (see pitfall #1)
#   - always include "Ad-hoc Verifikation" disclaimer in the final summary

set -u

# ========== CONFIG ==========
REPO="/absolute/path/to/repo"
COMMIT_SHA="abc1234"
TARGET_FILES=(
  "${REPO}/path/to/file1"
  "${REPO}/path/to/file2"
)
GREP_CHECKS=(
  "expected-string-1|description of check 1"
  "expected-string-2|description of check 2"
)
BEHAVIORAL_CMD=""  # command to run for behavioral check, or empty
BEHAVIORAL_MATCH=""  # substring expected in output
# =============================

PASS=0
FAIL=0
ok()  { echo "  [PASS] $1"; PASS=$((PASS+1)); }
err() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

cd "$REPO"

echo "=== 1. Git state ==="
HEAD=$(git rev-parse --short HEAD)
[ "$HEAD" = "$COMMIT_SHA" ] && ok "HEAD = $COMMIT_SHA" || err "HEAD = $HEAD (expected $COMMIT_SHA)"
[ "$(git branch --show-current)" = "main" ] && ok "branch = main" || err "branch != main"

echo
echo "=== 2. Syntax checks ==="
for f in "${TARGET_FILES[@]}"; do
  case "$f" in
    *.sh) bash -n "$f" && ok "bash -n $f" || err "bash syntax: $f" ;;
    *.py) python3 -m py_compile "$f" && ok "py compile $f" || err "py syntax: $f" ;;
    *.ino) ok "arduino sketch $f (build-verified separately)" ;;
    *) ok "no syntax check for $f" ;;
  esac
done

echo
echo "=== 3. Patch presence ==="
for check in "${GREP_CHECKS[@]}"; do
  pattern="${check%%|*}"
  desc="${check##*|}"
  found=0
  for f in "${TARGET_FILES[@]}"; do
    if [ -f "$f" ] && grep -qF "$pattern" "$f"; then
      found=1
      break
    fi
  done
  [ $found -eq 1 ] && ok "$desc" || err "$desc (pattern not found: '$pattern')"
done

echo
echo "=== 4. Behavioral check ==="
if [ -n "$BEHAVIORAL_CMD" ]; then
  output=$(eval "$BEHAVIORAL_CMD" 2>&1 || true)
  if echo "$output" | grep -qF "$BEHAVIORAL_MATCH"; then
    ok "behavioral: '$BEHAVIORAL_MATCH' found in output"
  else
    err "behavioral: '$BEHAVIORAL_MATCH' not found"
    echo "  DEBUG output: $(echo "$output" | head -3)"
  fi
else
  ok "no behavioral check configured"
fi

echo
echo "=== 5. Regression (existing tests) ==="
if [ -f "${REPO}/scripts/flashlib/tests" ] || [ -d "${REPO}/scripts/flashlib/tests" ]; then
  cd "${REPO}/scripts" 2>/dev/null
  TEST_OUTPUT=$(python3 -m pytest flashlib/tests/ -q 2>&1 || true)
  cd "$REPO"
  if echo "$TEST_OUTPUT" | grep -qE "[0-9]+ passed"; then
    N=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ passed" | head -1)
    ok "regression: $N"
  else
    err "regression: tests not green"
  fi
else
  ok "no regression suite to run"
fi

echo
echo "=== 6. Pushed to origin ==="
git fetch origin main --quiet 2>/dev/null
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] && ok "origin/main = HEAD" || err "origin != HEAD"

echo
echo "================================================"
echo "  PASS: $PASS    FAIL: $FAIL"
echo "================================================"
[ $FAIL -eq 0 ]