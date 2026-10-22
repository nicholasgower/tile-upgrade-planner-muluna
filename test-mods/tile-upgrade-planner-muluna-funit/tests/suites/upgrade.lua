-- Runtime tests for the tile upgrade engine. These call the same
-- upgrade_area_for_force function used by the planner; the only difference is
-- that a headless server has no player, so the suite resolves the force
-- directly instead of through a player.
local runner = require("__funit__.test_runner")
local helpers = require("__tile-upgrade-planner-muluna-funit__.tests.helpers")

local function fresh_surface()
  return helpers.surface()
end

local function upgrade(surface, area, filters)
  helpers.funit("upgrade_area_for_force", helpers.force().name, surface.index, area, filters)
end

local function box(x1, y1, x2, y2)
  return {
    left_top = { x = x1, y = y1 },
    right_bottom = { x = x2, y = y2 },
  }
end

runner.test("upgrade_area_for_force marks matching tiles with target ghosts", function()
  local surface = fresh_surface()
  helpers.set_tiles(surface, "stone-path", 0, 0, 2, 0)

  upgrade(surface, box(-1, -1, 4, 2), { ["stone-path"] = "concrete" })

  local ghosts = helpers.tile_ghosts(surface)
  runner.assert(helpers.count_tile_ghosts(surface) == 3, "expected three tile ghosts")
  for x = 0, 2 do
    runner.assert(ghosts[x .. ",0"] == "concrete", "tile " .. x .. ",0 was not marked for concrete")
  end
end)

runner.test("upgrade_area_for_force skips tiles already at the target", function()
  local surface = fresh_surface()
  helpers.set_tiles(surface, "concrete", 4, 4, 4, 4)
  helpers.set_tiles(surface, "stone-path", 5, 4, 5, 4)

  upgrade(surface, box(3, 3, 7, 6), { ["stone-path"] = "concrete" })

  local ghosts = helpers.tile_ghosts(surface)
  runner.assert(helpers.count_tile_ghosts(surface) == 1, "expected only one tile ghost")
  runner.assert(ghosts["5,4"] == "concrete", "the stone-path tile was not marked")
  runner.assert(ghosts["4,4"] == nil, "an already-concrete tile was marked")
end)

runner.test("upgrade_area_for_force rewrites a source tile ghost", function()
  local surface = fresh_surface()
  local area = box(6, 6, 10, 10)
  helpers.set_tiles(surface, "stone-path", 8, 8, 8, 8)
  local old = helpers.create_tile_ghost(surface, "stone-path", { x = 8, y = 8 })
  runner.assert(old and old.valid, "failed to create the source tile ghost")

  upgrade(surface, area, { ["stone-path"] = "concrete" })

  local ghosts = helpers.tile_ghosts(surface, area)
  runner.assert(helpers.count_tile_ghosts(surface, area) == 1, "expected exactly one replacement ghost")
  runner.assert(ghosts["8,8"] == "concrete", "source ghost was not replaced with concrete")
  runner.assert(not old.valid, "the old source ghost was not destroyed")
end)

runner.test("upgrade_area_for_force ignores invalid source tile names", function()
  local surface = fresh_surface()
  helpers.set_tiles(surface, "stone-path", 10, 10, 10, 10)

  upgrade(surface, box(9, 9, 12, 12), {
    ["stone-path"] = "concrete",
    ["not-a-real-tile"] = "concrete",
  })

  local ghosts = helpers.tile_ghosts(surface)
  runner.assert(helpers.count_tile_ghosts(surface) == 1, "expected one ghost despite the invalid source name")
  runner.assert(ghosts["10,10"] == "concrete", "valid mapping was not applied")
end)

runner.test("upgrade_area_for_force supports reverse mappings", function()
  local surface = fresh_surface()
  helpers.set_tiles(surface, "concrete", 14, 14, 14, 14)

  upgrade(surface, box(13, 13, 16, 16), { ["concrete"] = "stone-path" })

  local ghosts = helpers.tile_ghosts(surface)
  runner.assert(ghosts["14,14"] == "stone-path", "reverse mapping was not applied")
end)

runner.test("clear_area_for_force destroys tile ghosts only in the area", function()
  local surface = fresh_surface()
  helpers.create_tile_ghost(surface, "concrete", { x = 18, y = 18 })
  helpers.create_tile_ghost(surface, "concrete", { x = 30, y = 30 })

  helpers.funit("clear_area_for_force", helpers.force().name, surface.index, box(17, 17, 20, 20))

  local ghosts = helpers.tile_ghosts(surface)
  runner.assert(ghosts["18,18"] == nil, "ghost inside the cleared area survived")
  runner.assert(ghosts["30,30"] == "concrete", "ghost outside the cleared area was destroyed")
end)
