# FUnit CI helpers

These scripts are adapted from the [FUnit](https://gitlab.com/jfletcher94/funit)
GitHub Actions template, via
[planet-muluna](https://github.com/nicholasgower/planet-muluna)'s
`.github/funit/` helpers. They are licensed under
`LGPL-3.0-or-later WITH FUnit-CI-Exception`; the exception permits
project-specific CI adaptations to be copied and modified without applying
copyleft to this repository.

Sources (FUnit commit `b69c2f277a467726e3a8c555d48df5b647ec5a64`):

- `entrypoint.sh` — `entrypoint.sh`
- `prepare_test_environment.sh` — `scripts/prepare_test_environment.sh`
- `parse_funit_json.rb` — `scripts/parse_funit_json.rb`

## Project-specific changes

- The mod is a single-mod repository at the root, and its suite lives in
  `test-mods/tile-upgrade-planner-muluna-funit`, which the release
  `.gitattributes` excludes from the mod archive.
- `entrypoint.sh` runs Factorio in the background, watches the log for FUnit's
  `====END====` marker and kills the process, so no `pkill`/`timeout` dependency
  is needed. It removes stale reports and `mod-settings.dat` before each run.
- `prepare_test_environment.sh` reads from `artifacts/${MOD_NAME}` and copies the
  server settings into `$CONFIG`.
- `download_mods.py` is intentionally not vendored: this mod has no required
  external mod dependencies, so CI needs no mod-portal credentials. FUnit is
  public and is packaged from a shallow GitLab clone at the pinned commit.
- The workflow runs two profiles (`base` and `space-age`) from the same scenario.
  The base profile explicitly disables the expansion mods because omitted
  mod-list entries default to enabled.

## Scenario

The scenario lives inside the companion mod at
`test-mods/tile-upgrade-planner-muluna-funit/scenarios/__funit__tile_upgrade_planner`.
The build job copies it to the top-level `scenarios/` directory so the Factorio
image can load it by name. Its `control.lua` still requires the suites from
`__tile-upgrade-planner-muluna-funit__`.

The `muluna` profile is local-only (`PROFILE=muluna test-mods/.../run.sh`); CI
does not download the Muluna development mod set.
