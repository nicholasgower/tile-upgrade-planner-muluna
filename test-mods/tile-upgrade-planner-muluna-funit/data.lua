-- Data-stage entry point for the Tile Upgrade Planner FUnit fixtures.
--
-- The companion mod exists only for testing. It records data-stage checks in a
-- mod-data prototype so the runtime scenario can report them as FUnit tests.

data:extend({
  {
    type = "mod-data",
    name = "tile-upgrade-planner-funit-results",
    data = {
      -- [suite name][check id] = { ok = boolean, err = string|nil }
    },
  },
})

if settings.startup["tile-upgrade-planner-funit-enable-data-fixtures"].value then
  local manifest = require("prototypes.fixtures.manifest")
  for _, fixture in ipairs(manifest.data or {}) do
    require("prototypes.fixtures." .. fixture)
  end
end
