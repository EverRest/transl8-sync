#!/usr/bin/env bash
# Runs the `script:` of transl8-pull.yml under a POSIX `sh` (dash). The job
# image node:22-alpine has busybox ash and no bash, so bash-only syntax
# must fail here. `npx` is stubbed on PATH, so the test needs no network.
#
# Usage: bash gitlab/transl8-pull.test.sh (from any directory)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
TEMPLATE="$PWD/transl8-pull.yml"
SH=$(command -v dash || echo sh)

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
mkdir "$WORKDIR/bin" "$WORKDIR/job"

# The multi-line `- |` block of the transl8-pull job, de-indented.
awk '/^    - \|$/ {on=1; next} /^  artifacts:/ {on=0} on {sub(/^      /, ""); print}' \
  "$TEMPLATE" > "$WORKDIR/script.sh"
[ -s "$WORKDIR/script.sh" ] || { echo "FAIL could not extract the script from $TEMPLATE"; exit 1; }

cat > "$WORKDIR/bin/npx" <<'STUB'
#!/bin/sh
echo "$@" >> "$CALLS_LOG"
echo "{\"locale\":\"$7\"}"
STUB
chmod +x "$WORKDIR/bin/npx"

export CALLS_LOG="$WORKDIR/calls.log"
: > "$CALLS_LOG"
(
  cd "$WORKDIR/job"
  mkdir -p locales # the template's separate first `script:` item
  PATH="$WORKDIR/bin:$PATH" TRANSL8_PROJECT=my-project TRANSL8_LOCALES=fr,de,ja \
    TRANSL8_FORMAT=json "$SH" -e "$WORKDIR/script.sh"
)

fail=0
check() {
  if [ "$2" = "$3" ]; then echo "OK   $1"; else echo "FAIL $1 (expected [$2], got [$3])"; fail=1; fi
}
check "one CLI call per locale" "3" "$(wc -l < "$CALLS_LOG" | tr -d ' ')"
check "pull args carry project, locale and format" \
  "-y -p @transl8.ai/api-client@2 transl8 pull my-project de --format=json" "$(sed -n 2p "$CALLS_LOG")"
check "writes locales/<locale>.json for each locale" "de.json fr.json ja.json" \
  "$(cd "$WORKDIR/job/locales" && echo *)"
check "each file holds that locale's pull output" '{"locale":"ja"}' "$(cat "$WORKDIR/job/locales/ja.json")"

# Edge cases: a `*` in the list must not glob into file names, and an empty
# list must fail (like run.sh in the repository root), not "succeed" with no files.
: > "$CALLS_LOG"
touch "$WORKDIR/job/glob-bait.txt"
(cd "$WORKDIR/job" && PATH="$WORKDIR/bin:$PATH" TRANSL8_PROJECT=p TRANSL8_LOCALES='*' \
  TRANSL8_FORMAT=json "$SH" -e "$WORKDIR/script.sh")
check "a '*' locale is not globbed into file names" \
  "-y -p @transl8.ai/api-client@2 transl8 pull p * --format=json" "$(cat "$CALLS_LOG")"

: > "$CALLS_LOG"
rc=0
(cd "$WORKDIR/job" && PATH="$WORKDIR/bin:$PATH" TRANSL8_PROJECT=p TRANSL8_LOCALES='' \
  TRANSL8_FORMAT=json "$SH" -e "$WORKDIR/script.sh") 2>/dev/null || rc=$?
check "an empty TRANSL8_LOCALES fails" "1" "$rc"
check "an empty TRANSL8_LOCALES calls the CLI zero times" "0" "$(wc -l < "$CALLS_LOG" | tr -d ' ')"
[ "$fail" -eq 0 ]
