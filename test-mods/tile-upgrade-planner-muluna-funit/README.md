# tile-upgrade-planner-muluna-funit

Development-only [FUnit](https://mods.factorio.com/mod/funit) suite for
**tile-upgrade-planner-muluna**. This companion mod is not part of a normal
install: `test-mods/` is marked `export-ignore` in `.gitattributes`, so it is
excluded from release zips.

The suite has two parts:

1. **Data-stage fixtures** in `prototypes/fixtures/` inspect the final prototype
   set and the shared mod-data table, and record pass/fail results in the
   `tile-upgrade-planner-funit-results` mod-data prototype. They are controlled
   by the `tile-upgrade-planner-funit-enable-data-fixtures` startup setting
   (enabled by default). The runtime suite fails if it is disabled, so fixtures
   cannot be skipped silently.
2. **Runtime tests** in `tests/suites/` assert those results and exercise the
   player-independent tile upgrade engine, filter helpers and queue on a real
   surface.

`scenarios/__funit__tile_upgrade_planner/control.lua` starts FUnit, chooses a
report name from the active profile, and loads every runtime suite in
`tests/manifest.lua`.

## Running

From the repository root:

```sh
PROFILE=base      bash test-mods/tile-upgrade-planner-muluna-funit/run.sh
PROFILE=space-age bash test-mods/tile-upgrade-planner-muluna-funit/run.sh
PROFILE=muluna    bash test-mods/tile-upgrade-planner-muluna-funit/run.sh
```

`PROFILE=muluna` requires an installed Muluna development mod set. The runner
links `planet-muluna`, `PlanetsLib`, `muluna-graphics` and the other dependencies
from `FACTORIO_MODS`.

The runner is headless and self-contained:

- links the **current worktree** as `tile-upgrade-planner-muluna`;
- links the test mod and FUnit (plus Muluna dependencies for that profile);
- writes a scratch mod directory, config and logs under `TMP_ROOT`;
- disables server auto-pause so FUnit can advance ticks without a player;
- stops Factorio after FUnit prints `====END====`;
- exits non-zero on any FUnit `FAILURE` or `ERROR`.

Useful environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `FACTORIO_BIN` | `/opt/factorio_space_age_21/bin/x64/factorio` | Factorio executable |
| `FACTORIO_MODS` | `<install>/mods` | Directory containing dependency mods |
| `PROFILE` | `base` | `base`, `space-age` or `muluna` |
| `TMP_ROOT` | `/tmp/opencode/tile-upgrade-planner-funit-<profile>` | Scratch mod directory, config and logs |
| `TIMEOUT` | `600` | Seconds to wait for `====END====` |
| `FACTORIO_PORT` | `34199` | Local server port for the headless instance |

The full log is `$TMP_ROOT/stdout.log`; the FUnit report is
`$TMP_ROOT/write-data/script-output/funit-report-tile-upgrade-planner-<profile>.json`.
On failure the runner prints the relevant FUnit lines and the tail of the log.

## Requirements

- Factorio 2.1.
- The `funit` mod (the runner links `funit_*.zip` from `FACTORIO_MODS`).
- For `PROFILE=muluna`: the Muluna development mod set (`planet-muluna`,
  `PlanetsLib`, `muluna-graphics`, `flib`, `bplib`, `rigor-module`,
  `item-request-proxy-events`, `module-category-defaults`, the
  space-exploration graphics mods and `alien-biomes-graphics`).
- `factorio` must be able to bind `FACTORIO_PORT` (or set another port).

The scenario is started with:

```text
--start-server-load-scenario tile-upgrade-planner-muluna-funit/__funit__tile_upgrade_planner
```

## Layout

```text
info.json, settings.lua     companion-mod metadata and fixture setting
data.lua                    creates the result bag, runs data-stage fixtures
data-updates.lua            data-updates fixtures (currently empty)
data-final-fixes.lua        data-final-fixes fixtures (after the mod's own patches)
prototypes/fixtures/        prototype-level checks, grouped by feature
lib/results.lua             records fixture results in mod-data
scenarios/__funit__.../     FUnit scenario entry point
tests/helpers.lua           dedicated test surface, tile and ghost helpers
tests/manifest.lua          runtime suite load order
tests/suites/               runtime behavioral suites
run.sh                      headless runner
```

## Test-only production seams

Most math and tile operations are reachable through normal Factorio APIs. A few
paths resolve a player, which a headless server does not have (Factorio 2.1 has
no `game.create_player`). `script/funit.lua` exposes a
`tile_upgrade_planner_funit` remote interface **only when the `funit` mod is
active**:

- `get_storage`, `get_shared`
- `verify_filters`, `get_filters`, `invert_table`, `area_size`
- `ensure_planner`, `clear_planner`, `set_planner_target`
- `enqueue_area`, `enqueue_clear`, `reset_queue`, `process_queue`
- `upgrade_area_for_force`, `clear_area_for_force`

The production modules export their internals through the returned module table
in `script/gui.lua` / `script/planner.lua`. They are inert in normal play.

Queued tasks accept an optional `force_name`. Normal play never sets it; the
tests use it to drive the queue without a player.

## Adding a test

1. **Prototype-only check:** add `results.check("suite", "id", function() ... end)`
   to a file in `prototypes/fixtures/` and list it in the matching stage array
   in `prototypes/fixtures/manifest.lua`.
2. **Runtime behavior:** add a suite under `tests/suites/`, register it in
   `tests/manifest.lua`, and use `runner.test` / `runner.assert`.
3. If you add a data fixture, add its ID to the explicit `EXPECTED` list in
   `tests/suites/data_fixtures.lua`. A missing result must fail.
4. Use `tests/helpers.lua` for the dedicated surface, tile placement and ghost
   queries. Clean up entities, ghosts, queue state and planner storage at the end
   of the test.
5. Run the base and space-age profiles and check both `SUCCESS` lines and the
   exit code. Run the muluna profile when touching compatibility.

Runtime tests must not assume a player exists. Use `surface.create_entity`, the
`tile_upgrade_planner_funit` interface, and `runner.after_n_ticks_do` to wait for
real tick handlers.

## Coverage notes and limitations

The suite covers:

- selection tool, shortcut, custom input, sprite and mod-data contracts;
- the `"mod-openable"` flag that lets Factorio pin a configured planner instance
  to the quickbar instead of an item-type filter;
- the default mapping and the documented cross-mod extension point;
- Muluna's `space-platform-foundation -> low-density-space-platform-foundation`
  insertion when Muluna is active;
- runtime storage initialization and the remote seam;
- filter conversion, prototype validation, geometry and per-planner seeding;
- tile ghost creation for bare tiles, target tiles, existing source ghosts,
  invalid sources and reverse mappings;
- area-limited ghost clearing;
- large-area queue splitting, processing, clearing, reset and stale-force tasks.

Player-driven paths remain manual: the cursor/GUI event handlers, row add/remove,
open/close planner, selection input wiring, and `gvv` integration. Quickbar
pinning is covered only at the data-contract level (the `"mod-openable"` flag);
the actual quickbar slot type requires a player, so it is verified manually on a
save with a character. See `AGENTS.md` for the full conventions and known quirks.
