-- Runtime FUnit scenario for tile-upgrade-planner-muluna.
--
-- The scenario lives inside the development-only companion mod so it is not
-- included in release builds. Run it with the local runner or the Factorio
-- command line as:
--   --start-server-load-scenario tile-upgrade-planner-muluna-funit/__funit__tile_upgrade_planner
require("__base__/script/freeplay/control.lua")

local runner = require("__funit__.test_runner")
runner.register("tile-upgrade-planner-muluna")

local profile = "base"
if script.active_mods["planet-muluna"] then
  profile = "muluna"
elseif script.active_mods["space-age"] then
  profile = "space-age"
end
runner.report("tile-upgrade-planner-" .. profile)

local manifest = require("__tile-upgrade-planner-muluna-funit__.tests.manifest")
for _, suite in ipairs(manifest) do
  require(suite)
end
