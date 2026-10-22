-- Startup setting for the data-stage fixtures.
--
-- Keeping the fixtures behind a setting lets a save load when the test mod is
-- still installed but the fixtures are deliberately disabled. The runtime
-- suite fails if they are disabled, so they cannot be skipped silently.
data:extend({
  {
    type = "bool-setting",
    setting_type = "startup",
    name = "tile-upgrade-planner-funit-enable-data-fixtures",
    default_value = true,
    order = "a",
  },
})
