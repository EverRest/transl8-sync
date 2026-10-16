#!/usr/bin/env bash
# The logic behind the composite step in action.yml. It is a plain script
# so that run.test.sh can run it directly. A `run:` block inside YAML cannot
# be tested this way.
#
# This script reads TRANSL8_* env vars (action.yml sets them from its
# inputs) and calls the transl8 CLI from the @transl8.ai/api-client package.
# The package name and the bin name differ, so the command is
# `npx -p <package> <bin>`. The package is pinned to major version 2, so a
# new major release cannot break your pipeline without a change from you.
set -euo pipefail

RUN="${TRANSL8_CLI_RUNNER:-npx -y -p @transl8.ai/api-client@2 transl8}"

case "$TRANSL8_COMMAND" in
  pull)
    mkdir -p "$TRANSL8_OUT_DIR"
    if [ -z "$TRANSL8_LOCALES" ]; then
      echo "::error::transl8-sync: 'locales' is required for command=pull" >&2
      exit 1
    fi
    IFS=',' read -ra LOCALE_LIST <<< "$TRANSL8_LOCALES"
    for LOCALE in "${LOCALE_LIST[@]}"; do
      $RUN pull "$TRANSL8_PROJECT" "$LOCALE" --format="$TRANSL8_FORMAT" \
        > "$TRANSL8_OUT_DIR/$LOCALE.$TRANSL8_FORMAT"
    done
    ;;
  push)
    if [ -z "$TRANSL8_FILE" ]; then
      echo "::error::transl8-sync: 'file' is required for command=push" >&2
      exit 1
    fi
    $RUN push "$TRANSL8_FILE" --project="$TRANSL8_PROJECT"
    ;;
  *)
    echo "::error::transl8-sync: unknown command '$TRANSL8_COMMAND' (expected pull or push)" >&2
    exit 1
    ;;
esac
