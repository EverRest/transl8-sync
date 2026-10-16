#!/usr/bin/env bash
# Runs run.sh directly. A `run:` block inside action.yml cannot be tested
# this way. The test replaces TRANSL8_CLI_RUNNER with a stub, so it needs no
# network, no registry and no real credentials. It tests the wiring of
# run.sh, not a live server.
#
# Usage: bash run.test.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" # the repository root, where run.sh lives

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

CALLS_LOG="$WORKDIR/calls.log"
# A stand-in for `npx -y -p @transl8.ai/api-client@2 transl8` that records its
# args and prints a fixed body, so run.sh's *branching* is what's under test.
cat > "$WORKDIR/fake-cli.sh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$CALLS_LOG"
if [ "$1" = "pull" ]; then
  echo "{\"locale\":\"$3\"}"
elif [ "$1" = "push" ]; then
  echo "{\"applied\":true}"
fi
EOF
chmod +x "$WORKDIR/fake-cli.sh"

pass=0
fail=0

check() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "OK   $name"
    pass=$((pass + 1))
  else
    echo "FAIL $name (expected [$expected], got [$actual])"
    fail=$((fail + 1))
  fi
}

DEFAULT_RUN=$(grep -E '^RUN=' run.sh)
check "default CLI runner uses the published npm package" "true" \
  "$(echo "$DEFAULT_RUN" | grep -q 'npx -y -p @transl8.ai/api-client@2 transl8' && echo true || echo false)"

# --- pull: single locale ---
rm -f "$CALLS_LOG"
OUT_DIR="$WORKDIR/out1"
TRANSL8_CLI_RUNNER="$WORKDIR/fake-cli.sh" \
TRANSL8_PROJECT=my-project TRANSL8_COMMAND=pull TRANSL8_LOCALES=fr \
TRANSL8_FORMAT=json TRANSL8_FILE= TRANSL8_OUT_DIR="$OUT_DIR" \
CALLS_LOG="$CALLS_LOG" \
  bash ./run.sh
check "pull writes fr.json" "true" "$([ -f "$OUT_DIR/fr.json" ] && echo true || echo false)"
check "pull calls the CLI with project+locale+format" \
  "pull my-project fr --format=json" "$(cat "$CALLS_LOG")"

# --- pull: multiple locales ---
rm -f "$CALLS_LOG"
OUT_DIR="$WORKDIR/out2"
TRANSL8_CLI_RUNNER="$WORKDIR/fake-cli.sh" \
TRANSL8_PROJECT=p TRANSL8_COMMAND=pull TRANSL8_LOCALES=fr,de,ja \
TRANSL8_FORMAT=json TRANSL8_FILE= TRANSL8_OUT_DIR="$OUT_DIR" \
CALLS_LOG="$CALLS_LOG" \
  bash ./run.sh
check "pull (multi-locale) writes one file per locale" "3" \
  "$(ls "$OUT_DIR" | wc -l | tr -d ' ')"
check "pull (multi-locale) calls the CLI once per locale" "3" \
  "$(wc -l < "$CALLS_LOG" | tr -d ' ')"

# --- pull: missing locales fails loudly ---
rm -f "$CALLS_LOG"
set +e
TRANSL8_CLI_RUNNER="$WORKDIR/fake-cli.sh" \
TRANSL8_PROJECT=p TRANSL8_COMMAND=pull TRANSL8_LOCALES= \
TRANSL8_FORMAT=json TRANSL8_FILE= TRANSL8_OUT_DIR="$WORKDIR/out3" \
CALLS_LOG="$CALLS_LOG" \
  bash ./run.sh 2>"$WORKDIR/err3.log"
CODE=$?
set -e
check "pull with no locales exits non-zero" "1" "$CODE"
check "pull with no locales names the missing input" "true" \
  "$(grep -q "'locales' is required" "$WORKDIR/err3.log" && echo true || echo false)"

# --- push ---
rm -f "$CALLS_LOG"
echo '{"fr":"Bonjour"}' > "$WORKDIR/fr.json"
TRANSL8_CLI_RUNNER="$WORKDIR/fake-cli.sh" \
TRANSL8_PROJECT=my-project TRANSL8_COMMAND=push TRANSL8_LOCALES= \
TRANSL8_FORMAT=json TRANSL8_FILE="$WORKDIR/fr.json" TRANSL8_OUT_DIR=. \
CALLS_LOG="$CALLS_LOG" \
  bash ./run.sh
check "push calls the CLI with the file and project" \
  "push $WORKDIR/fr.json --project=my-project" "$(cat "$CALLS_LOG")"

# --- push: missing file fails loudly ---
set +e
TRANSL8_CLI_RUNNER="$WORKDIR/fake-cli.sh" \
TRANSL8_PROJECT=p TRANSL8_COMMAND=push TRANSL8_LOCALES= \
TRANSL8_FORMAT=json TRANSL8_FILE= TRANSL8_OUT_DIR=. \
CALLS_LOG="$CALLS_LOG" \
  bash ./run.sh 2>"$WORKDIR/err5.log"
CODE=$?
set -e
check "push with no file exits non-zero" "1" "$CODE"

# --- unknown command ---
set +e
TRANSL8_CLI_RUNNER="$WORKDIR/fake-cli.sh" \
TRANSL8_PROJECT=p TRANSL8_COMMAND=frobnicate TRANSL8_LOCALES= \
TRANSL8_FORMAT=json TRANSL8_FILE= TRANSL8_OUT_DIR=. \
CALLS_LOG="$CALLS_LOG" \
  bash ./run.sh 2>"$WORKDIR/err6.log"
CODE=$?
set -e
check "unknown command exits non-zero" "1" "$CODE"

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
