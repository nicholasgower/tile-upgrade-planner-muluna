-- Core runtime smoke tests: storage initialization, runtime prototypes and the
-- test-only remote interface.
local runner = require("__funit__.test_runner")
local helpers = require("__tile-upgrade-planner-muluna-funit__.tests.helpers")

runner.test("storage is initialized on init", function()
  local storage = helpers.storage()
  runner.assert(type(storage) == "table", "get_storage did not return a table")
  runner.assert(type(storage.guis) == "table", "storage.guis is missing")
  runner.assert(type(storage.planner) == "table", "storage.planner is missing")
  runner.assert(type(storage.tasks) == "table", "storage.tasks is missing")
  runner.assert(storage.tasks.front == 1, "storage.tasks.front should start at 1")
  runner.assert(storage.tasks.back == 1, "storage.tasks.back should start at 1")
end)

runner.test("shared mod-data is readable at runtime", function()
  local shared = helpers.funit("get_shared")
  runner.assert(type(shared) == "table", "get_shared did not return a table")
  runner.assert(shared.names.planner == "tile-upgrade-planner", "unexpected planner name")
  runner.assert(shared.names.mod == "tile-upgrade-planner-muluna", "unexpected mod name")
  runner.assert(type(shared.default_mapping) == "table", "default_mapping is missing at runtime")
end)

runner.test("runtime prototypes expose the planner tool", function()
  local tools = prototypes.get_item_filtered({ { filter = "selection-tool" } })
  runner.assert(tools["tile-upgrade-planner"], "selection-tool prototype is missing at runtime")
  runner.assert(prototypes.item["tile-upgrade-planner"], "planner item prototype is missing at runtime")
  runner.assert(prototypes.custom_input["tile-upgrade-planner"], "custom input prototype is missing at runtime")
  runner.assert(prototypes.shortcut["tile-upgrade-planner"], "shortcut prototype is missing at runtime")
end)

runner.test("funit remote interface is registered", function()
  runner.assert(
    remote.interfaces["tile_upgrade_planner_funit"],
    "tile_upgrade_planner_funit remote interface is missing"
  )
  runner.assert(
    remote.interfaces["tile_upgrade_planner_funit"].upgrade_area_for_force == true,
    "upgrade_area_for_force seam is missing"
  )
  runner.assert(
    remote.interfaces["__funit_mock_event__tile-upgrade-planner-muluna"],
    "mod did not register with FUnit's event mocker"
  )
end)
