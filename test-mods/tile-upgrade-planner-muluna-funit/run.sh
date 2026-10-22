#!/usr/bin/env bash
# Headless FUnit runner for tile-upgrade-planner-muluna.
#
# Usage:
#   test-mods/tile-upgrade-planner-muluna-funit/run.sh
#
# Environment:
#   FACTORIO_BIN   Factorio executable (default: /opt/factorio_space_age_21/bin/x64/factorio)
#   FACTORIO_MODS  Source mod directory containing dependencies (default: sibling mods dir)
#   PROFILE        base (default), space-age, or muluna
#   TMP_ROOT       Scratch directory (default: /tmp/opencode/tile-upgrade-planner-funit-<profile>)
#   TIMEOUT        Maximum run time in seconds (default: 600)
#   FACTORIO_PORT  Local server port (default: 34199)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

FACTORIO_BIN="${FACTORIO_BIN:-/opt/factorio_space_age_21/bin/x64/factorio}"
FACTORIO_MODS="${FACTORIO_MODS:-$(dirname "$(dirname "$(dirname "$FACTORIO_BIN")")")/mods}"
PROFILE="${PROFILE:-base}"
TMP_ROOT="${TMP_ROOT:-/tmp/opencode/tile-upgrade-planner-funit-$PROFILE}"
TIMEOUT="${TIMEOUT:-600}"
FACTORIO_PORT="${FACTORIO_PORT:-34199}"

MOD_NAME="tile-upgrade-planner-muluna"
TEST_MOD_NAME="tile-upgrade-planner-muluna-funit"
SCENARIO="__funit__tile_upgrade_planner"

case "$PROFILE" in
  base|space-age|muluna) ;;
  *)
    echo "Unknown PROFILE '$PROFILE' (expected base, space-age or muluna)." >&2
    exit 1
    ;;
esac

if [[ ! -x "$FACTORIO_BIN" ]]; then
  echo "Factorio binary not found: $FACTORIO_BIN" >&2
  exit 1
fi
if [[ ! -d "$FACTORIO_MODS" ]]; then
  echo "Factorio mod directory not found: $FACTORIO_MODS" >&2
  exit 1
fi

rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT/mods" "$TMP_ROOT/write-data/script-output" "$TMP_ROOT/write-data/saves"

link_path() {
  local name="$1"
  local source="$2"
  if [[ ! -e "$source" ]]; then
    echo "Required dependency missing: $source" >&2
    exit 1
  fi
  ln -sfn "$source" "$TMP_ROOT/mods/$name"
}

# Prefer an unpacked directory, otherwise the newest matching zip.
link_dependency() {
  local name="$1"
  local source="$FACTORIO_MODS/$name"
  if [[ -e "$source" ]]; then
    link_path "$name" "$source"
    return
  fi
  source="$(find "$FACTORIO_MODS" -maxdepth 1 -name "${name}_*.zip" -type f | sort -V | tail -n 1)"
  if [[ -z "$source" ]]; then
    echo "Required dependency missing: ${name} (directory or ${name}_*.zip)" >&2
    exit 1
  fi
  link_path "$(basename "$source")" "$source"
}

link_path "$MOD_NAME" "$REPO_DIR"
link_path "$TEST_MOD_NAME" "$SCRIPT_DIR"
link_dependency "funit"

write_mod_list_header() {
  cat <<'JSON'
{
  "mods": [
    { "name": "base", "enabled": true },
JSON
}

write_mod_list_footer() {
  cat <<JSON
    { "name": "$MOD_NAME", "enabled": true },
    { "name": "$TEST_MOD_NAME", "enabled": true },
    { "name": "funit", "enabled": true }
  ]
}
JSON
}

{
  write_mod_list_header
  if [[ "$PROFILE" != "base" ]]; then
    cat <<'JSON'
    { "name": "elevated-rails", "enabled": true },
    { "name": "quality", "enabled": true },
    { "name": "recycler", "enabled": true },
    { "name": "space-age", "enabled": true },
JSON
  else
    # Missing entries default to enabled, so the base profile must disable the
    # expansion mods explicitly.
    cat <<'JSON'
    { "name": "elevated-rails", "enabled": false },
    { "name": "quality", "enabled": false },
    { "name": "recycler", "enabled": false },
    { "name": "space-age", "enabled": false },
JSON
  fi

  if [[ "$PROFILE" == "muluna" ]]; then
    link_dependency "planet-muluna"
    for dependency in \
      PlanetsLib muluna-graphics flib bplib rigor-module item-request-proxy-events \
      module-category-defaults space-exploration-graphics space-exploration-graphics-4 \
      space-exploration-graphics-5 alien-biomes-graphics; do
      link_dependency "$dependency"
    done
    cat <<'JSON'
    { "name": "planet-muluna", "enabled": true },
    { "name": "PlanetsLib", "enabled": true },
    { "name": "muluna-graphics", "enabled": true },
    { "name": "flib", "enabled": true },
    { "name": "bplib", "enabled": true },
    { "name": "rigor-module", "enabled": true },
    { "name": "item-request-proxy-events", "enabled": true },
    { "name": "module-category-defaults", "enabled": true },
    { "name": "space-exploration-graphics", "enabled": true },
    { "name": "space-exploration-graphics-4", "enabled": true },
    { "name": "space-exploration-graphics-5", "enabled": true },
    { "name": "alien-biomes-graphics", "enabled": true },
JSON
  fi

  write_mod_list_footer
} > "$TMP_ROOT/mods/mod-list.json"

cat > "$TMP_ROOT/server-settings.json" <<'JSON'
{
  "name": "tile-upgrade-planner FUnit",
  "description": "Headless FUnit run for tile-upgrade-planner-muluna",
  "tags": [],
  "max_players": 1,
  "visibility": {
    "public": false,
    "lan": false
  },
  "username": "funit",
  "token": "",
  "game_password": "",
  "require_user_verification": false,
  "allow_commands": "admins-only",
  "autosave_interval": 0,
  "autosave_slots": 1,
  "afk_autokick_interval": 0,
  "auto_pause": false,
  "auto_pause_when_players_connect": false,
  "only_admins_can_pause_the_game": true,
  "autosave_only_on_server": true
}
JSON

cat > "$TMP_ROOT/config.ini" <<EOF
; version=13
[path]
read-data=__PATH__executable__/../../data
write-data=$TMP_ROOT/write-data

[general]
locale=en

[other]
; verbose-logging=false
EOF

LOG="$TMP_ROOT/stdout.log"
echo "Running Tile Upgrade Planner FUnit suite (profile: $PROFILE)..."
echo "  binary: $FACTORIO_BIN"
echo "  mods:   $TMP_ROOT/mods"
echo "  log:    $LOG"

set +e
"$FACTORIO_BIN" \
  --config "$TMP_ROOT/config.ini" \
  --mod-directory "$TMP_ROOT/mods" \
  --start-server-load-scenario "$TEST_MOD_NAME/$SCENARIO" \
  --port "$FACTORIO_PORT" \
  --server-settings "$TMP_ROOT/server-settings.json" \
  --disable-audio \
  --no-log-rotation \
  >"$LOG" 2>&1 &
FACTORIO_PID=$!
set -e

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

if [[ ! -f "$LOG" ]]; then
  echo "No Factorio log was produced at $LOG." >&2
  exit 1
fi

if [[ "$finished" -ne 1 ]]; then
  echo "FUnit did not reach ====END==== within ${TIMEOUT}s." >&2
  grep -nE '__FUNIT__|Error|error|FAILURE|ERROR' "$LOG" | tail -n 80 >&2 || true
  tail -n 80 "$LOG" >&2 || true
  exit 1
fi

if grep -qE '__FUNIT__.*(FAILURE__|ERROR__)' "$LOG"; then
  echo "FUnit reported failures:" >&2
  grep -nE '__FUNIT__.*(FAILURE__|ERROR__)' "$LOG" >&2
  exit 1
fi

echo "FUnit suite passed."
grep -oE '__FUNIT__[^ ]*====BEGIN [0-9]+ TESTS====' "$LOG" | tail -n 1 || true
grep -c '__FUNIT__.*SUCCESS__' "$LOG" | sed 's/^/SUCCESS lines: /' || true
if compgen -G "$TMP_ROOT/write-data/script-output/funit-report-*.json" >/dev/null; then
  echo "Report: $(ls "$TMP_ROOT"/write-data/script-output/funit-report-*.json | tail -n 1)"
fi
