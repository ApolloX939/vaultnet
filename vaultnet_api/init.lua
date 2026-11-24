vaultnet = {
	modname = core.get_current_modname(),
	modpath = core.get_modpath(core.get_current_modname()),
	version = "0.1.5",
}

local src = vaultnet.modpath .. "/src/"
dofile(src .. "util.lua")
dofile(src .. "materials.lua")
dofile(src .. "registry.lua")
dofile(src .. "power.lua")
dofile(src .. "access.lua")
dofile(src .. "drive.lua")
dofile(src .. "network.lua")
dofile(src .. "visuals.lua")
dofile(src .. "storage.lua")
