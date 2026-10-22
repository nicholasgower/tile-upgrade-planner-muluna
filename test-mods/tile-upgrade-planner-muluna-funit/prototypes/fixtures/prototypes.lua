-- Data-stage contract checks for the prototypes and shared mod-data table.
local results = require("lib.results")

local SUITE = "prototypes"
local PLANNER = "tile-upgrade-planner"

local function contains(list, value)
  for _, item in pairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

local function find_mapping(mapping, source, target)
  for _, entry in pairs(mapping or {}) do
    if entry.source == source and entry.target == target then
      return true
    end
  end
  return false
end

results.check(SUITE, "selection-tool", function()
  local tool = data.raw["selection-tool"][PLANNER]
  assert(tool, "selection-tool '" .. PLANNER .. "' is missing")
  assert(tool.stack_size == 1, "selection tool stack_size should be 1")
  assert(tool.flags and contains(tool.flags, "spawnable"), "selection tool should be spawnable")
  assert(tool.subgroup == "tool", "selection tool should be in the 'tool' subgroup")
  assert(tool.icons and #tool.icons == 2, "selection tool should have two icon layers")
  assert(tool.select and contains(tool.select.mode, "tile-ghost"), "selection tool select mode should include tile-ghost")
  assert(tool.alt_select and contains(tool.alt_select.mode, "tile-ghost"), "alt_select mode should include tile-ghost")
  assert(
    tool.alt_select.entity_filters and contains(tool.alt_select.entity_filters, "tile-ghost"),
    "alt_select should be filtered to tile ghosts"
  )
end)

results.check(SUITE, "quickbar-instance", function()
  -- Without "mod-openable", Factorio treats a custom selection-tool as a plain
  -- item in the quickbar: the slot becomes an item-type filter and clicking it
  -- produces a new planner with no stored filters. With the flag, the quickbar
  -- pins the specific item instance, so its item_number (and stored filters)
  -- are preserved. This is engine behaviour, not a mod API.
  local tool = data.raw["selection-tool"][PLANNER]
  assert(
    tool.flags and contains(tool.flags, "mod-openable"),
    "selection tool must have the 'mod-openable' flag so the quickbar pins a configured planner instance"
  )
end)

results.check(SUITE, "shortcut", function()
  local shortcut = data.raw["shortcut"][PLANNER]
  assert(shortcut, "shortcut '" .. PLANNER .. "' is missing")
  assert(shortcut.action == "spawn-item", "shortcut action should be spawn-item")
  assert(shortcut.item_to_spawn == PLANNER, "shortcut should spawn the planner")
  assert(shortcut.associated_control_input == PLANNER, "shortcut should use the planner custom input")
  assert(shortcut.technology_to_unlock == "construction-robotics", "shortcut should unlock with construction robotics")
end)

results.check(SUITE, "custom-input", function()
  local input = data.raw["custom-input"][PLANNER]
  assert(input, "custom-input '" .. PLANNER .. "' is missing")
  assert(input.action == "spawn-item", "custom input action should be spawn-item")
  assert(input.item_to_spawn == PLANNER, "custom input should spawn the planner")
  assert(type(input.key_sequence) == "string" and input.key_sequence ~= "", "custom input needs a key sequence")
end)

results.check(SUITE, "sprites", function()
  for _, name in ipairs({ "tile-upgrade-add-row", "tile-upgrade-remove-row" }) do
    assert(data.raw["sprite"][name], "sprite '" .. name .. "' is missing")
  end
end)

results.check(SUITE, "mod-data", function()
  local bag = data.raw["mod-data"][PLANNER]
  assert(bag, "mod-data '" .. PLANNER .. "' is missing")
  local shared = bag.data
  assert(type(shared) == "table", "mod-data payload should be a table")
  assert(shared.names, "mod-data payload is missing names")
  assert(shared.names.planner == PLANNER, "planner name changed unexpectedly")
  assert(shared.names.mod == "tile-upgrade-planner-muluna", "mod name changed unexpectedly")
  assert(type(shared.default_mapping) == "table", "default_mapping is missing")
end)

results.check(SUITE, "tile-filters", function()
  local shared = data.raw["mod-data"][PLANNER].data
  assert(type(shared.tile_filters) == "table", "tile_filters is missing")
  local has_item_to_place = false
  for _, filter in pairs(shared.tile_filters) do
    if filter.filter == "item-to-place" then
      has_item_to_place = true
    end
  end
  assert(has_item_to_place, "tile_filters should include an item-to-place filter")
end)

results.check(SUITE, "default-mapping", function()
  local mapping = data.raw["mod-data"][PLANNER].data.default_mapping
  assert(#mapping >= 4, "default_mapping should contain at least the four vanilla base entries")
  assert(find_mapping(mapping, "stone-path", "concrete"), "stone-path -> concrete is missing")
  assert(find_mapping(mapping, "concrete", "refined-concrete"), "concrete -> refined-concrete is missing")
  assert(
    find_mapping(mapping, "hazard-concrete-left", "refined-hazard-concrete-left"),
    "hazard-concrete-left -> refined-hazard-concrete-left is missing"
  )
  assert(
    find_mapping(mapping, "hazard-concrete-right", "refined-hazard-concrete-right"),
    "hazard-concrete-right -> refined-hazard-concrete-right is missing"
  )

  for _, entry in pairs(mapping) do
    assert(data.raw["tile"][entry.source], "default mapping source '" .. tostring(entry.source) .. "' is not a tile")
    assert(data.raw["tile"][entry.target], "default mapping target '" .. tostring(entry.target) .. "' is not a tile")
  end
end)

results.check(SUITE, "extension-point", function()
  -- This is the documented way for other mods to add tiles (see README).
  local mapping = data.raw["mod-data"][PLANNER].data.default_mapping
  local before = #mapping
  mapping[#mapping + 1] = { source = "concrete", target = "stone-path" }
  assert(#mapping == before + 1, "default_mapping is not an extendable array")
  table.remove(mapping)
  assert(#mapping == before, "default_mapping was not restored after the extension check")
end)
