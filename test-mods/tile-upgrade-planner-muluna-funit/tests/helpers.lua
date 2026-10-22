-- Shared helpers for the Tile Upgrade Planner FUnit runtime suites.
local helpers = {}

local SURFACE_NAME = "tile-upgrade-planner-funit"
local PAD = {
  left_top = { -16, -16 },
  right_bottom = { 48, 48 },
}

function helpers.pad()
  return PAD
end

function helpers.force()
  return game.forces["player"]
end

---Get (or create) the dedicated test surface and flatten a pad around the origin.
---
---The surface is created once per save and reused, so every suite must clean up
---the entities and ghosts it creates. Landfill removes cliffs/water and makes
---tile placement deterministic.
---@return LuaSurface
function helpers.surface()
  local surface = game.surfaces[SURFACE_NAME]
  if not surface then
    surface = game.create_surface(SURFACE_NAME, { seed = 1234 })
  end

  surface.request_to_generate_chunks({ 16, 16 }, 2)
  surface.force_generate_chunk_requests()

  helpers.clear_entities(surface, PAD)
  helpers.set_tiles(surface, "landfill", PAD.left_top[1], PAD.left_top[2], PAD.right_bottom[1] - 1, PAD.right_bottom[2] - 1)
  helpers.clear_entities(surface, PAD)
  return surface
end

function helpers.clear_entities(surface, area)
  if not surface or not surface.valid then
    return
  end
  for _, entity in pairs(surface.find_entities_filtered({ area = area })) do
    if entity.valid and entity.type ~= "character" then
      entity.destroy()
    end
  end
end

function helpers.clear_ghosts(surface, area)
  for _, ghost in pairs(surface.find_entities_filtered({ area = area, name = "tile-ghost" })) do
    if ghost.valid then
      ghost.destroy()
    end
  end
end

---Set every tile in a rectangle (inclusive) to one tile prototype.
---@param surface LuaSurface
---@param tile_name string
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
function helpers.set_tiles(surface, tile_name, x1, y1, x2, y2)
  local tiles = {}
  for x = x1, x2 do
    for y = y1, y2 do
      tiles[#tiles + 1] = { name = tile_name, position = { x = x, y = y } }
    end
  end
  surface.set_tiles(tiles, true, true, true, false)
end

---Create a tile ghost centered on the given tile position.
---@param surface LuaSurface
---@param inner_name string
---@param tile_position TilePosition
---@param force? LuaForce
---@return LuaEntity?
function helpers.create_tile_ghost(surface, inner_name, tile_position, force)
  return surface.create_entity({
    name = "tile-ghost",
    inner_name = inner_name,
    position = { x = tile_position.x + 0.5, y = tile_position.y + 0.5 },
    force = force or helpers.force(),
    raise_built = true,
  })
end

---Map tile ghosts in an area by their tile position: ["x,y"] = inner tile name.
function helpers.tile_ghosts(surface, area)
  local out = {}
  for _, ghost in pairs(surface.find_entities_filtered({ area = area or PAD, name = "tile-ghost" })) do
    local x = math.floor(ghost.position.x)
    local y = math.floor(ghost.position.y)
    out[x .. "," .. y] = ghost.ghost_name
  end
  return out
end

function helpers.count_tile_ghosts(surface, area)
  return #surface.find_entities_filtered({ area = area or PAD, name = "tile-ghost" })
end

function helpers.funit(name, ...)
  return remote.call("tile_upgrade_planner_funit", name, ...)
end

function helpers.storage()
  return helpers.funit("get_storage")
end

function helpers.reset_queue()
  helpers.funit("reset_queue")
end

return helpers
