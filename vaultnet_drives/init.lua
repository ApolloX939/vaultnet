local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local S = core.settings

local TIERS = {
	{name = "Tiny", capacity = 1024},
	{name = "Mini", capacity = 2048},
	{name = "Small", capacity = 4096},
	{name = "Medium", capacity = 8192},
	{name = "Large", capacity = 16384},
	{name = "Big", capacity = 32768},
	{name = "Huge", capacity = 65536},
	{name = "Giant", capacity = 262144},
	{name = "Massive", capacity = 1048576},
	{name = "Colossal", capacity = 4194304},
}

local function state_image(base)
	return function(state)
		return base .. "^vaultnet_drives_light" .. state .. ".png"
	end
end

for i, tier in ipairs(TIERS) do
	local capacity = tonumber(S:get("vaultnet_drives_capacity_" .. i)) or tier.capacity
	local base = "vaultnet_drives_drive" .. i .. ".png"

	core.register_craftitem(modname .. ":drive" .. i, {
		description = tier.name .. " VaultNet Drive",
		inventory_image = state_image(base)(1),
		wield_image = state_image(base)(1),
		stack_max = 1, -- contents live in the stack's meta
		groups = {vaultnet_drive = 1},
		vaultnet_drive = {
			capacity = capacity,
			state_image = state_image(base),
		},
	})
end

if core.get_modpath("default") then
	dofile(modpath .. "/recipes_mtg.lua")
end
