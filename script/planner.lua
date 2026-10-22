local shared = prototypes.mod_data["tile-upgrade-planner"].data
local util = require("util")

local Public = {}

local function invert_table(tab)
    local out = {}
    local i = 1
    for k,v in pairs(tab) do
        out[i] = k
        i = i + 1
    end
    return out
end

local function get_filters(planner_data)
    local out = {}
    for _,v in pairs(planner_data) do
        if v.source and v.target then
            out[v.source] = v.target
        end
    end
    return out
end

local function area_size(area)
    return (area.right_bottom.x - area.left_top.x) * (area.right_bottom.y - area.left_top.y)
end

local function enqueue_area(player_id, surface_id, area, filters, force_name)
    local queue = storage.tasks
    local block_size = 1024
    for x = area.left_top.x, area.right_bottom.x, block_size do
        for y = area.left_top.y, area.right_bottom.y, block_size do
            local left_top = {x=x, y=y}
            local right_bottom = {x= math.min(x+block_size, area.right_bottom.x), y=math.min(y+block_size,area.right_bottom.y)}
            queue[queue.back] = {
                player_id = player_id, 
                surface_id=surface_id, 
                force_name = force_name,
                area = {
                    left_top=left_top,
                    right_bottom=right_bottom,
                },
                filters=filters,
            }
            queue.back = queue.back + 1
        end
    end
end

---Apply a source->target tile mapping to every tile and tile ghost in an area.
---This is the player-independent core of the planner. `force_name` on queued
---tasks is a test-only seam; normal play resolves the force from the player.
---@param force LuaForce
---@param surface LuaSurface
---@param area BoundingBox
---@param filters table<string, string>
---@param player? LuaPlayer
local function upgrade_area_for_force(force, surface, area, filters, player)
    local filters_inv = invert_table(filters)
    for key,item in pairs(table.deepcopy(filters_inv)) do 
        if prototypes.tile[item] == nil then
            filters_inv[key] = nil
        end
    end

    local upgrade_locations = {}
    local item_index = 0
    for _,ghost in pairs(surface.find_entities_filtered({area=area,name="tile-ghost",force=force})) do
        local ghost_name = ghost.ghost_name
        local position = ghost.position
        if filters[ghost_name] then
            if surface.get_tile(position).name ~= filters[ghost_name] then
                surface.create_entity{name="tile-ghost",position=position,force=force,player=player,item_index = item_index, raise_built=true,inner_name=filters[ghost_name]}
                item_index = 1
            end
            ghost.destroy()
        end
        upgrade_locations[position.x-0.5 .. "," ..position.y-0.5] = true
    end
    local tiles = surface.find_tiles_filtered({area=area,name=filters_inv})
    for _,tile in pairs(tiles) do
        local tile_name = tile.name
        local tile_position = tile.position
        if filters[tile_name] and not upgrade_locations[tile_position.x .. "," ..tile_position.y] then
            surface.create_entity{name="tile-ghost",position=tile_position,force=force,item_index = item_index,player=player,raise_built=true,inner_name=filters[tile_name]}
            item_index = 1
        end
    end
end

local function upgrade_area(player_id, surface_id, area, filters)
    local player = game.get_player(player_id)
    if not player then
        return
    end
    upgrade_area_for_force(player.force, game.get_surface(surface_id), area, filters, player)
end

local function selected_area(event, reverse)
    local player = game.get_player(event.player_index)
    local planner = player.cursor_stack
    if planner then
        if planner.valid_for_read and planner.name == shared.names.planner then
            -- A planner that never went through open_planner (on_player_cursor_stack_changed) has no entry yet:
            -- give it the defaults, as the GUI does, instead of passing nil to get_filters.
            storage.planner[planner.item_number] = storage.planner[planner.item_number] or util.copy(shared.default_mapping)
            local filters = util.copy(storage.planner[planner.item_number])
            if reverse then
                for _,v in pairs(filters) do
                    v.source, v.target = v.target, v.source
                end
            end
            if area_size(event.area) > 100000 then
                enqueue_area(event.player_index, event.surface.index, event.area, get_filters(filters))
            else
                upgrade_area(event.player_index, event.surface.index, event.area, get_filters(filters))
            end
        end
    end
end

-- local function update_tick_rate(event) 
--     local queue = storage.tasks
--     game.print("back = " .. queue.back)
--     game.print("front = " .. queue.front)
--     if queue.back - queue.front > 3  then
--         storage.tick_wait = 1
--     else
--         storage.tick_wait = 240
--     end
--     game.print(storage.tick_wait)
-- end

local function clear_area_for_force(force, surface, area)
    for _,ghost in pairs(surface.find_entities_filtered{area=area,name="tile-ghost",force=force}) do
        ghost.destroy()
    end
end

-- Kept as a global for compatibility with older scripts that called it
-- directly. New code should use clear_area_for_force or the player resolver.
function clear_area(player_id, surface_id, area, filters)
    local player = game.get_player(player_id)
    if not player then
        return
    end
    clear_area_for_force(player.force, game.get_surface(surface_id), area)
end

local function process_queue(event)
        local queue = storage.tasks
        local data = queue[queue.front]
        if data then
            local surface = game.get_surface(data.surface_id)
            local player = data.player_id and game.get_player(data.player_id)
            local force = data.force_name and game.forces[data.force_name]
            if not force and player then
                force = player.force
            end
            if surface and force then
                if data.filters then
                    upgrade_area_for_force(force, surface, data.area, data.filters, player)
                else
                    clear_area_for_force(force, surface, data.area)
                end
            end
            queue[queue.front] = nil
            queue.front = queue.front + 1
            if queue.front >= queue.back then
                queue.front = 1
                queue.back = 1
            end
        end
end

local function deselected_area(event)
    if event.item == shared.names.planner then
        for _,ent in pairs(event.entities) do
            ent.destroy()
        end
    end
end

script.on_event(defines.events.on_player_selected_area, function(event) selected_area(event, false) end)
script.on_event(defines.events.on_player_reverse_selected_area, function(event) selected_area(event, true) end)
script.on_event(defines.events.on_player_alt_selected_area, deselected_area)
script.on_nth_tick(60, process_queue)

Public.invert_table = invert_table
Public.get_filters = get_filters
Public.area_size = area_size
Public.enqueue_area = enqueue_area
Public.upgrade_area_for_force = upgrade_area_for_force
Public.upgrade_area = upgrade_area
Public.clear_area_for_force = clear_area_for_force
Public.clear_area = clear_area
Public.process_queue = process_queue

return Public
