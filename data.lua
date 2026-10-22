
local shared = require("shared")

data:extend({
  {
    name = shared.names.planner,
    type = "selection-tool",
    icons = {
      {
        icon = "__tile-upgrade-planner-muluna__/graphics/icons/tile-upgrade-planner-frame.png",
        icon_size = 64,
      },
      {
        icon = "__tile-upgrade-planner-muluna__/graphics/icons/tile-upgrade-planner-outline.png",
        icon_size = 64,
        scale = 0.875,
      },
    },
    subgroup = "tool",
    flags = {"spawnable", "mod-openable"},
    order = "c[automated-construction]-c[upgrade-planner]-tile",
    stack_size = 1,
    select = {
      border_color = {g=255},
      cursor_box_type = "blueprint-snap-rectangle", --entity?
      mode = {"items-to-place", "tile-ghost"},  -- any-tile?
    },
    alt_select = {
      border_color = {b=255},
      cursor_box_type = "not-allowed",
      mode = {"items-to-place", "tile-ghost"}, --is tile-ghost broken now?
      entity_filters = {"tile-ghost"}
    },
    reverse_select = {
      border_color = {g=255},
      cursor_box_type = "blueprint-snap-rectangle",
      mode = {"items-to-place", "tile-ghost"},  -- any-tile?
    },
  },
  {
    name = shared.names.planner,
    type = "shortcut",
    action = "spawn-item",
    item_to_spawn = "tile-upgrade-planner",
    style = "green",
    order = "b[blueprints]-h[upgrade-planner]",
    associated_control_input = shared.names.planner,
    technology_to_unlock = "construction-robotics",
    unavailable_until_unlocked = false,
    icons = {
      {
        icon = "__tile-upgrade-planner-muluna__/graphics/icons/shortcut-toolbar/tile-upgrade-planner-x64.png",
        priority = "extra-high-no-scale",
        icon_size = 64,
        flags = {"gui-icon"}
      },
    },
    small_icons = {
      {
        icon = "__tile-upgrade-planner-muluna__/graphics/icons/shortcut-toolbar/tile-upgrade-planner-x24.png",
        priority = "extra-high-no-scale",
        icon_size = 24,
        flags = {"gui-icon"}
      }
    },
    disabled_small_icon = {
      filename = "__tile-upgrade-planner-muluna__/graphics/icons/shortcut-toolbar/tile-upgrade-planner-x24-white.png",
      priority = "extra-high-no-scale",
      size = 24,
      flags = {"gui-icon"}
    },
  },
  {
    name = shared.names.planner,
    type = "custom-input",
    key_sequence = "SHIFT + ALT + U",
    item_to_spawn = shared.names.planner,
    action = "spawn-item",
  },
  {
    name = shared.names.add_row,
    type = "sprite",
    filename = "__core__/graphics/add-icon.png",
    size = 32,
    tint = {g=255},
  },
  {
    name = shared.names.remove_row,
    type = "sprite",
    filename = "__core__/graphics/cancel.png",
    size = 64,
    scale = 0.5,
    --tint = {r=255},
  },
  {
    name = "tile-upgrade-planner",
    type = "mod-data",
    data = {
      
    }
  }
})

data.raw["mod-data"]["tile-upgrade-planner"].data = shared
