-- Test-only remote interface used by the FUnit scenario.
--
-- This file is required from control.lua only when the funit mod is active,
-- so every function here is inert in normal play. It exposes the planner's
-- player-independent core plus a few storage helpers because a headless
-- Factorio server has no players and cannot drive the GUI or cursor paths.

local gui = require("script.gui")
local planner = require("script.planner")

local Public = {}

remote.add_interface("tile_upgrade_planner_funit", {
    get_storage = function()
        return storage
    end,

    get_shared = function()
        return prototypes.mod_data["tile-upgrade-planner"].data
    end,

    verify_filters = gui.verify_filters,
    get_filters = planner.get_filters,
    invert_table = planner.invert_table,
    area_size = planner.area_size,

    -- GUI planners are keyed by the selection tool's item_number. Creating one
    -- only mutates storage, so it can be exercised without a player.
    ensure_planner = gui.ensure_planner,
    clear_planner = function(planner_id)
        storage.planner[planner_id] = nil
    end,
    set_planner_target = function(planner_id, row, target)
        storage.planner[planner_id][row].target = target
    end,

    enqueue_area = planner.enqueue_area,
    enqueue_clear = function(surface_id, area, force_name)
        local queue = storage.tasks
        queue[queue.back] = {
            surface_id = surface_id,
            force_name = force_name,
            area = area,
        }
        queue.back = queue.back + 1
    end,
    reset_queue = function()
        storage.tasks = {front = 1, back = 1}
    end,
    process_queue = function()
        planner.process_queue()
    end,

    upgrade_area_for_force = function(force_name, surface_id, area, filters)
        return planner.upgrade_area_for_force(
            game.forces[force_name],
            game.get_surface(surface_id),
            area,
            filters
        )
    end,

    clear_area_for_force = function(force_name, surface_id, area)
        return planner.clear_area_for_force(
            game.forces[force_name],
            game.get_surface(surface_id),
            area
        )
    end,
})

return Public
