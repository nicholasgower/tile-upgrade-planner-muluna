
require("script/gui")
require("script/planner")


if script.active_mods["gvv"] then require("__gvv__.gvv")() end

if script.active_mods["funit"] then
    require("script.funit")
    require("__funit__.mock").register()
end
