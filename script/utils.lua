
require "util"

local library = {}

--[[
    Merges two table together, performing a shallow copy of any top-level keys.
    Returns a new object so that the original ones are unaffected
    @param source_table the original table to copy
    @param merge_table the table to merge into the source table. Any intersecting keys uses the values in this table
    @return the merged table
]]
library.merge_table = function(source_table, merge_table)
    local output_table = util.table.deepcopy(source_table)
    for k,v in pairs(merge_table) do 
        output_table[k] = v
    end
    return output_table
end

-- compares two string version numbers, like those given by on_configuration_changed
-- returns <0 if oldVersion is older and >0 if newVersion is older, 0 if they're equal
library.version_compare = function(oldVersion, newVersion)
    local old, new = {major,minor,patch}, {major,minor,patch}
    _,_,old.major,old.minor,old.patch = string.find(oldVersion,"(%d+)%.(%d+)%.(%d+)")
    _,_,new.major,new.minor,new.patch = string.find(newVersion,"(%d+)%.(%d+)%.(%d+)")
    if new.major ~= old.major then
        return old.major - new.major
    elseif new.minor ~= old.minor then
        return old.minor - new.minor
    elseif new.patch ~= old.patch then
        return old.patch - new.patch
    else
        return 0
    end
end

-- returns true if the given version is older than the version to compare it to.
-- if the version is nil, it returns false
library.is_version_older_than = function(oldVersion, compareVersion)
    if oldVersion and compareVersion then
        return version_compare(oldVersion, compareVersion) < 0
    else
        return false
    end
end

-- Copies the given prototype and returns one with the new name, setting its mining/place result appropriately
-- @param type The type of the prototype to copy
-- @param name The name of the prototype to copy
-- @param newName The name the copy will have
-- @return The copied entity
library.copy_prototype = function(type, name, newName)
    if not data.raw[type][name] then error("type " .. type .. " " .. name .. " does not exist") end
    local prototype = util.table.deepcopy(data.raw[type][name])
    prototype.name = newName
    if prototype.minable and prototype.minable.result then
        prototype.minable.result = newName
    end
    if prototype.place_result then
        prototype.place_result = newName
    end
    if prototype.result then
        prototype.result = newName
    end
    if prototype.results then
        prototype.results = {{name=newName, amount=1}}
    end
    return prototype
end

-- Returns a read-only table.  Gives an error when attempting to change the values of the table
-- @param t the table to be made read-only
-- @reaturn a read-only copy of the source table
library.read_only = function(t)
    local proxy = {}
    local mt = {       
        __index = t,
        __newindex = function (t,k,v)
            error("attempt to update a read-only table", 2)
        end
    }
    setmetatable(proxy, mt)
    return proxy
end


-- returns the distance between two positions.  Positions are either an array with {x,y} or an indexed table
library.distance_between = function(pos1, pos2)
    local p1 = {
        x = pos1.x or pos1[1],
        y = pos1.y or pos1[2]
    }
    local p2 = {
        x = pos2.x or pos2[1],
        y = pos2.y or pos2[2]
    }
    return ((p1.x-p2.x)^2 + (p1.y-p2.y)^2)^0.5
end

-- Calculates the velocity needed to travel the distance given and the kinetic energy to reach that speed
-- @param distance the distance to launch a projectile
-- @param gravity the local gravity.  Defaults to 9.81 if not provided
-- @return [1] the energy needed, in joules
-- @return [2] the velocity the projectile needs to travel that far
library.calculate_energy_cost = function(distance, gravity)
  local velocity = (distance*(gravity or 9.81))^0.5
  local energy = (global.settings.mass*velocity^2)/2
  return energy, velocity
end

local entity_types = {
    "arrow",
    "artillery-flare",
    "artillery-projectile",
    "beam",
    "character-corpse",
    "cliff",
    "corpse",
    "rail-remnants",
    "deconstructible-tile-proxy",
    "entity-ghost",
    "accumulator",
    "artillery-turret",
    "beacon",
    "boiler",
    "burner-generator",
    "character",
    "arithmetic-combinator",
    "decider-combinator",
    "constant-combinator",
    "container",
    "logistic-container",
    "infinity-container",
    "assembling-machine",
    "rocket-silo",
    "furnace",
    "electric-energy-interface",
    "electric-pole",
    "unit-spawner",
    "fish",
    "combat-robot",
    "construction-robot",
    "logistic-robot",
    "gate",
    "generator",
    "heat-interface",
    "heat-pipe",
    "inserter",
    "lab",
    "lamp",
    "land-mine",
    "market",
    "mining-drill",
    "offshore-pump",
    "pipe",
    "infinity-pipe",
    "pipe-to-ground",
    "player-port",
    "power-switch",
    "programmable-speaker",
    "pump",
    "radar",
    "curved-rail",
    "straight-rail",
    "rail-chain-signal",
    "rail-signal",
    "reactor",
    "roboport",
    "simple-entity",
    "simple-entity-with-owner",
    "simple-entity-with-force",
    "solar-panel",
    "storage-tank",
    "train-stop",
    "loader-1x1",
    "loader",
    "splitter",
    "transport-belt",
    "underground-belt",
    "tree",
    "turret",
    "ammo-turret",
    "electric-turret",
    "fluid-turret",
    "unit",
    "car",
    "artillery-wagon",
    "cargo-wagon",
    "fluid-wagon",
    "locomotive",
    "wall",
    "explosion",
    "flame-thrower-explosion",
    "fire",
    "stream",
    "flying-text",
    "highlight-box",
    "item-entity",
    "item-request-proxy",
    "particle-source",
    "projectile",
    "resource",
    "rocket-silo-rocket",
    "rocket-silo-rocket-shadow",
    "smoke-with-trigger",
    "speech-bubble",
    "sticker",
    "tile-ghost",
}

local item_types = {
    "item",
    "ammo",
    "capsule",
    "gun",
    "item-with-entity-data",
    "item-with-label",
    "item-with-inventory",
    "blueprint-book",
    "item-with-tags",
    "selection-tool",
    "blueprint",
    "copy-paste-tool",
    "deconstruction-item",
    "upgrade-item",
    "module",
    "rail-planner",
    "tool",
    "armor",
    "repair-tool",
}


-- Gets the item associated with this entity
-- @param entity the entity to get. Either a name (in which case it gets the entity with the same name) or a
--      prototype definition, in which case it gets the minable result
-- @return the prototype of the item
function library.get_item(entity)
    local name = entity
    if type(entity) == "table" then
        if entity.minable and entity.minable.result then
            name = entity.minable.result
        elseif entity.minable and entity.minable.results then
            name = entity.minable.results[1][1] or  entity.minable.results[1].name
        else
            name = entity.name
        end
    end
    if type(name) == "string" then
        for _,type in pairs(item_types) do
            if data.raw[type][name] then
                return data.raw[type][name]
            end
        end
        log("Item with name " .. name .. " was not found")
    else
        log("Couldn't resolve name for: " .. serpent.line(entity))
    end
    return nil
end











return library