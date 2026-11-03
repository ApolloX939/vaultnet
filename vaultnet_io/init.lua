local modpath = core.get_modpath(core.get_current_modname())

dofile(modpath .. "/terminal.lua")

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
