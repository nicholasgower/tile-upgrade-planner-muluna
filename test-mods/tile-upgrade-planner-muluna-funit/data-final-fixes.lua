-- Final data-stage fixtures for the Tile Upgrade Planner FUnit suite.
--
-- This runs after tile-upgrade-planner-muluna's data-final-fixes and after
-- other mods (including Muluna) have patched the shared mod-data table, so the
-- fixtures see the final prototype state that ships to players.
if settings.startup["tile-upgrade-planner-funit-enable-data-fixtures"].value then
  local manifest = require("prototypes.fixtures.manifest")
  for _, fixture in ipairs(manifest.data_final_fixes or {}) do
    require("prototypes.fixtures." .. fixture)
  end
end
