-- Data-updates fixtures for the Tile Upgrade Planner FUnit suite.
if settings.startup["tile-upgrade-planner-funit-enable-data-fixtures"].value then
  local manifest = require("prototypes.fixtures.manifest")
  for _, fixture in ipairs(manifest.data_updates or {}) do
    require("prototypes.fixtures." .. fixture)
  end
end
