-- Pure helper tests: row-to-filter conversion, prototype validation, geometry
-- and per-planner storage initialization.
local runner = require("__funit__.test_runner")
local helpers = require("__tile-upgrade-planner-muluna-funit__.tests.helpers")

runner.test("get_filters converts complete rows only", function()
  local filters = helpers.funit("get_filters", {
    { source = "stone-path", target = "concrete" },
    { source = "concrete", target = "refined-concrete" },
    { source = "sand-1" },
    { target = "landfill" },
  })
  runner.assert(filters["stone-path"] == "concrete", "stone-path mapping is missing")
  runner.assert(filters["concrete"] == "refined-concrete", "concrete mapping is missing")
  runner.assert(filters["sand-1"] == nil, "incomplete row should be ignored")
  runner.assert(not filters["landfill"], "target-only row should be ignored")
end)

runner.test("verify_filters keeps only placeable tile names", function()
  local verified = helpers.funit("verify_filters", {
    { source = "stone-path", target = "concrete" },
    { source = "not-a-real-tile", target = "concrete" },
    { target = "concrete" },
    { source = "stone-path", target = "not-a-real-tile" },
  })
  runner.assert(verified[1].source == "stone-path", "valid source was dropped")
  runner.assert(verified[1].target == "concrete", "valid target was dropped")
  runner.assert(verified[2].source == nil, "invalid source should be removed")
  runner.assert(verified[2].target == "concrete", "valid target next to an invalid source was dropped")
  runner.assert(verified[3].source == nil, "missing source should stay nil")
  runner.assert(verified[3].target == "concrete", "target-only row lost its target")
  runner.assert(verified[4].source == "stone-path", "valid source next to an invalid target was dropped")
  runner.assert(verified[4].target == nil, "invalid target should be removed")
end)

runner.test("invert_table returns the filter source names", function()
  local names = helpers.funit("invert_table", {
    ["stone-path"] = "concrete",
    ["concrete"] = "refined-concrete",
  })
  local found = {}
  for _, name in pairs(names) do
    found[name] = true
  end
  runner.assert(found["stone-path"], "stone-path key is missing")
  runner.assert(found["concrete"], "concrete key is missing")
  runner.assert(#names == 2, "expected two source names, got " .. #names)
end)

runner.test("area_size computes tile count", function()
  local size = helpers.funit("area_size", {
    left_top = { x = -10, y = 5 },
    right_bottom = { x = 10, y = 15 },
  })
  runner.assert(size == 200, "expected 200 tiles, got " .. tostring(size))
end)

runner.test("ensure_planner seeds storage without aliasing the default mapping", function()
  local planner_id = 987654
  local shared = helpers.funit("get_shared")
  local default_target = shared.default_mapping[1].target

  helpers.funit("clear_planner", planner_id)
  local rows = helpers.funit("ensure_planner", planner_id)
  runner.assert(type(rows) == "table", "ensure_planner did not return a table")
  runner.assert(#rows == #shared.default_mapping, "planner was not seeded with the default mapping")
  runner.assert(rows[1].source == shared.default_mapping[1].source, "first source does not match the default")
  runner.assert(rows[1].target == default_target, "first target does not match the default")

  -- Mutating the planner must not change the shared default mapping.
  helpers.funit("set_planner_target", planner_id, 1, "stone-path")
  local reread = helpers.funit("ensure_planner", planner_id)
  runner.assert(reread[1].target == "stone-path", "planner mutation did not persist in storage")
  runner.assert(
    helpers.funit("get_shared").default_mapping[1].target == default_target,
    "shared default_mapping was aliased into planner storage"
  )

  helpers.funit("clear_planner", planner_id)
end)
