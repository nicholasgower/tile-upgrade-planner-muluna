

local blacklist = {
    "landfill"
}

local tile_filters = {{filter="item-to-place"}}
--[[
    for _,v in pairs(blacklist) do
    tile_filters[#tile_filters + 1] = {
        filter = "name",
        name = v,
        mode = "and",
        invert = true
    }
end
--]]

local shared = {
    names = {
        planner = "tile-upgrade-planner",
        mod = "tile-upgrade-planner-muluna",
        add_row = "tile-upgrade-add-row",
        remove_row = "tile-upgrade-remove-row",
    },
    tile_filters = tile_filters,
    default_mapping = {
        {source="stone-path", target="concrete"},
        {source="concrete", target="refined-concrete"},
        {source="hazard-concrete-left", target="refined-hazard-concrete-left"},
        {source="hazard-concrete-right", target="refined-hazard-concrete-right"},
        --{source = "space-platform-foundation", target = "low-density-space-platform-foundation"} --Add this to Muluna
    },
}



--For modders, add to default mapping like this:
-- table.insert(data.raw["mod-data"]["tile-upgrade-planner"].data.default_mapping,{source = "space-platform-foundation", target = "low-density-space-platform-foundation"})

return shared
