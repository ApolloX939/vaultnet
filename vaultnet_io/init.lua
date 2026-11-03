local modpath = core.get_modpath(core.get_current_modname())

dofile(modpath .. "/terminal.lua")
dofile(modpath .. "/devices.lua")

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
