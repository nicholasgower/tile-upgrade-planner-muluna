-- Converts data-stage fixture results into FUnit tests.
--
-- The expected IDs are explicit so a fixture that silently stops recording an
-- entry fails the suite instead of disappearing from a pairs() loop.
local runner = require("__funit__.test_runner")

local results = prototypes.mod_data["tile-upgrade-planner-funit-results"]

local PREFIX = "data/"

local EXPECTED = {
  prototypes = {
    "selection-tool",
    "quickbar-instance",
    "shortcut",
    "custom-input",
    "sprites",
    "mod-data",
    "tile-filters",
    "default-mapping",
    "extension-point",
  },
}

if script.active_mods["planet-muluna"] then
  EXPECTED.compat = { "muluna-default-mapping" }
end

runner.test("data fixtures: startup fixtures are enabled", function()
  runner.assert(
    settings.startup["tile-upgrade-planner-funit-enable-data-fixtures"].value,
    "tile-upgrade-planner-funit-enable-data-fixtures is disabled; enable it to run the data-stage checks"
  )
end)

runner.test("data fixtures: result bag exists", function()
  runner.assert(results, "tile-upgrade-planner-funit-results mod-data is missing")
  runner.assert(type(results.data) == "table", "result bag data is not a table")
end)

local expected_suite_count = 0
for _ in pairs(EXPECTED) do
  expected_suite_count = expected_suite_count + 1
end

runner.test("data fixtures: expected suites are present", function()
  local actual = 0
  for suite in pairs(results and results.data or {}) do
    actual = actual + 1
    runner.assert(EXPECTED[suite], "unexpected data fixture suite '" .. tostring(suite) .. "'")
  end
  runner.assert(
    actual == expected_suite_count,
    "expected " .. expected_suite_count .. " data fixture suites, found " .. actual
  )
end)

for suite, ids in pairs(EXPECTED) do
  for _, id in ipairs(ids) do
    local check = results and results.data and results.data[suite] and results.data[suite][id]
    runner.test(PREFIX .. suite .. "/" .. id, function()
      runner.assert(check, "missing data fixture result '" .. suite .. "/" .. id .. "'")
      runner.assert(check.ok, check.err or "data fixture failed")
    end)
  end
end
