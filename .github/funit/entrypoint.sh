#!/bin/bash
# SPDX-License-Identifier: LGPL-3.0-or-later WITH FUnit-CI-Exception
#
# Headless FUnit scenario runner for the factoriotools/factorio image.
# Adapted from planet-muluna's CI helper. It runs every scenario listed in
# /scenario_names.txt, watches for FUnit's ====END==== marker, stops Factorio,
# and fails on any FUnit FAILURE/ERROR or missing end marker.

set -uo pipefail

MODS="${MODS:-/mods}"
CONFIG="${CONFIG:-/config}"
TIMEOUT="${TIMEOUT:-600}"
FACTORIO_BIN="${FACTORIO_BIN:-/opt/factorio/bin/x64/factorio}"
SCENARIO_NAMES="${SCENARIO_NAMES:-/scenario_names.txt}"

ANY_FAILURE=0

mkdir -p "$MODS" "$CONFIG" /factorio/saves /factorio/script-output

if [[ ! -x "$FACTORIO_BIN" ]]; then
    echo "Factorio binary not found: $FACTORIO_BIN" >&2
    exit 1
fi

if [[ ! -s "$SCENARIO_NAMES" ]]; then
    echo "No scenarios listed in $SCENARIO_NAMES" >&2
    exit 1
fi

cp /*.zip "$MODS"/ 2>/dev/null || true

while IFS= read -r fn; do
    [[ -z "$fn" ]] && continue
    echo "____SCENARIO____: $fn"

    rm -f "$MODS/mod-settings.dat" /factorio/script-output/funit-report-*.json
    if [[ -s "/factorio/scenarios/$fn/mod-list.json" ]]; then
        cp "/factorio/scenarios/$fn/mod-list.json" "$MODS/mod-list.json"
    else
        echo "Missing /factorio/scenarios/$fn/mod-list.json" >&2
        ANY_FAILURE=1
        continue
    fi

    LOG="/tmp/funit-${fn}.log"
    "$FACTORIO_BIN" \
        --start-server-load-scenario "$fn" \
        --mod-directory "$MODS" \
        --server-settings "$CONFIG/server-settings.json" \
        --disable-audio \
        --no-log-rotation \
        >"$LOG" 2>&1 &
    FACTORIO_PID=$!

    finished=0
    for ((i = 0; i < TIMEOUT; i++)); do
        if grep -q '====END====' "$LOG" 2>/dev/null; then
            finished=1
            break
        fi
        if ! kill -0 "$FACTORIO_PID" 2>/dev/null; then
            break
        fi
        sleep 1
    done

    if kill -0 "$FACTORIO_PID" 2>/dev/null; then
        kill "$FACTORIO_PID" 2>/dev/null || true
    fi
    wait "$FACTORIO_PID" 2>/dev/null || true

    cat "$LOG"

    if [[ "$finished" -ne 1 ]]; then
        echo "FUnit did not reach ====END==== within ${TIMEOUT}s for $fn." >&2
        ANY_FAILURE=1
        continue
    fi

    if grep -qE '__FUNIT__.*(FAILURE__|ERROR__)' "$LOG"; then
        echo "FUnit reported failures for $fn:" >&2
        grep -nE '__FUNIT__.*(FAILURE__|ERROR__)' "$LOG" >&2
        ANY_FAILURE=1
        continue
    fi

    echo "FUnit suite passed: $fn"
done < "$SCENARIO_NAMES"

exit "$ANY_FAILURE"
