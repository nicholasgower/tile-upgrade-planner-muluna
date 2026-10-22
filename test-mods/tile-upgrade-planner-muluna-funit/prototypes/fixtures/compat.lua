-- Compatibility fixture: Muluna adds its space-platform foundation tile to the
-- default mapping. Only record the check when Muluna is active; the base
-- profile is not expected to have it.
local results = require("lib.results")

if not mods["planet-muluna"] then
  return
end

local SUITE = "compat"

results.check(SUITE, "muluna-default-mapping", function()
  local mapping = data.raw["mod-data"]["tile-upgrade-planner"].data.default_mapping
  local found = false
  for _, entry in pairs(mapping) do
    if entry.source == "space-platform-foundation" and entry.target == "low-density-space-platform-foundation" then
      found = true
    end
  end
  assert(found, "Muluna's space-platform-foundation -> low-density-space-platform-foundation mapping is missing")
  assert(data.raw["tile"]["space-platform-foundation"], "space-platform-foundation tile is missing")
  assert(data.raw["tile"]["low-density-space-platform-foundation"], "low-density-space-platform-foundation tile is missing")
end)
