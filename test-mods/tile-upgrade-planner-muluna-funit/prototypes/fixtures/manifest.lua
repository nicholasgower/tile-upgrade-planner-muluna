-- Fixture manifest for the Tile Upgrade Planner FUnit suite.
--
-- Each list holds fixture module names inside prototypes/fixtures/. They are
-- required by the matching stage entry point (data.lua / data-updates.lua /
-- data-final-fixes.lua). All current fixtures run in data-final-fixes because
-- they inspect the final prototype set, including changes made by Muluna's
-- compatibility patch.
return {
  data = {},
  data_updates = {},
  data_final_fixes = {
    "prototypes",
    "compat",
  },
}
